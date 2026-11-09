# frozen_string_literal: true

module WebsiteScreenshotWorld
  # The Instant Snap API: capture a page on demand. Reach it through {Client#instant_snap}.
  #
  # The capture and submit methods take the API's options as keyword arguments with the API's own names.
  # Nested blocks are hashes, an option left out is not sent (an explicit +false+ is), and the keys of
  # +headers:+ and +cookies:+ are sent exactly as given.
  #
  # @example
  #   client.instant_snap.capture(url: "https://example.com", format: "webp", viewport: { width: 1440 })
  class InstantSnap < Service
    MISSING_KEY = "No Instant Snap API key was given: pass instant_snap_api_key: to " \
                  "WebsiteScreenshotWorld::Client.new or set WSW_INSTANT_SNAP_API_KEY."

    CAPTURES_PATH = "/instant-snap/v1/captures"
    private_constant :CAPTURES_PATH

    # Every option a capture accepts besides +url+. +response_type+ and +async+ are set by the method called.
    # +timeout+ (the browser time of an async capture) is taken by {#submit} and {#submit_to_bucket} only; on
    # the other capture methods +timeout:+ is the call's own timeout and the server refuses the option.
    CAPTURE_OPTIONS = %i[
      media_category format viewport device_category emulated_device scroll_mode auto_height max_height zoom
      block_ads block_pop_ups press_escape page_timeout_ms scrolling_delay_ms user_agent locale time_zone headers
      cookies
      geolocation selectors proxy timestamp_watermark page_source s3_delivery callback_url timeout
    ].freeze

    # Statuses {#wait} keeps polling through.
    UNFINISHED = [CaptureStatus::QUEUED, CaptureStatus::RUNNING, CaptureStatus::PENDING].freeze
    private_constant :UNFINISHED

    # @api private
    def initialize(capture_timeout:, **settings)
      super(**settings)
      @capture_timeout = capture_timeout
    end

    # Captures a page and answers with its metadata and a download link valid for 60 minutes.
    #
    # @param url [String] the page to capture, absolute http or https
    # @param idempotency_key [String, nil] makes the call safe to repeat; a random one is used otherwise
    # @param timeout [Numeric, nil] seconds to wait for the answer, retries included; defaults to the
    #   client's +capture_timeout+
    # @param options [Hash] any of {CAPTURE_OPTIONS}
    # @option options [String] :media_category one of {MediaCategory}
    # @option options [String] :format one of {Format}, belonging to the media category
    # @option options [Hash] :viewport +width+, +height+, +device_scale_factor+
    # @option options [String] :device_category one of {DeviceCategory}
    # @option options [String] :emulated_device a device from {#catalog}
    # @option options [String] :scroll_mode one of {ScrollMode}
    # @option options [Boolean] :auto_height
    # @option options [Integer] :max_height
    # @option options [Integer] :zoom percent, 50 to 100
    # @option options [Boolean] :block_ads
    # @option options [Boolean] :block_pop_ups
    # @option options [Boolean] :press_escape press Escape after the pop-up pass and again after scrolling,
    #   for a modal that closes on Escape
    # @option options [Integer] :page_timeout_ms
    # @option options [Integer] :scrolling_delay_ms the pause after each scroll step, 0 to 10000; default 500
    # @option options [String] :user_agent
    # @option options [String] :locale BCP 47
    # @option options [String] :time_zone IANA time zone
    # @option options [Hash{String => String}] :headers sent with every request the page makes
    # @option options [Hash{String => String}] :cookies set for the URL's origin
    # @option options [Hash] :geolocation +latitude+, +longitude+, +accuracy+
    # @option options [Hash] :selectors +xpath+, +click+, +hover+ (each at most 512 characters) and +hide+
    #   (up to 25 comma-separated CSS selectors, at most 2000 characters)
    # @option options [Hash] :proxy +country+, from {#catalog}
    # @option options [Hash] :timestamp_watermark +enabled+, +location+, +font_color+, +background_color+
    # @option options [Hash] :page_source +format+, one of {PageSourceFormat}
    # @option options [String] :callback_url also receives the capture's webhook
    # @return [Capture]
    # @raise [Error] a subclass matching the refusal
    def capture(url:, idempotency_key: nil, timeout: nil, **options)
      hash, response = post_capture(ResponseType::JSON, url, options, idempotency_key, timeout)
      Capture.from_api(hash, idempotent_replayed: replayed?(response))
    end

    # Captures a page and uploads the file to your S3-compatible bucket.
    #
    # @param s3_delivery [Hash] +access_key_id+, +secret_access_key+, +bucket+, and +region+ or
    #   +endpoint_url+; optionally +force_path_style+, +key_prefix+, +wait_for_sync+
    # @param (see #capture)
    # @option (see #capture)
    # @return [Capture] with {Capture#s3_delivery} describing the upload
    # @raise [Error] a subclass matching the refusal
    def capture_to_bucket(url:, s3_delivery:, idempotency_key: nil, timeout: nil, **options)
      options = options.merge(s3_delivery: s3_delivery)
      hash, response = post_capture(ResponseType::CLOUD_STORAGE, url, options, idempotency_key, timeout)
      Capture.from_api(hash, idempotent_replayed: replayed?(response))
    end

    # Captures a page and answers with the file itself, up to 64 MB.
    #
    # With a block, yields a {CaptureFile} whose body streams from the connection, and returns the block's
    # value. Without one, buffers the body to a +Tempfile+ and returns the {CaptureFile}; call
    # {CaptureFile#close} when done with it.
    #
    # @example
    #   client.instant_snap.capture_file(url: "https://example.com") { |file| file.save("page.png") }
    #
    # @param (see #capture)
    # @option (see #capture)
    # @yieldparam file [CaptureFile]
    # @return [CaptureFile, Object] the file, or the block's value
    # @raise [Error] a subclass matching the refusal
    def capture_file(url:, idempotency_key: nil, timeout: nil, **options)
      send_request(:post, CAPTURES_PATH,
                   body: capture_body(ResponseType::BY_FORMAT, url, options),
                   headers: capture_headers(idempotency_key),
                   accept: "*/*",
                   timeout: timeout || @capture_timeout) do |response|
        block_given? ? yield(CaptureFile.new(response)) : CaptureFile.buffered(response)
      end
    end

    # Submits an async capture and answers at once, before it runs, with the capture in status +queued+.
    # Follow it with {#wait}, {#get} or the +capture.succeeded+ / +capture.failed+ webhooks. A capture still
    # queued 15 minutes after it was accepted ends +failed+ with +capture_expired+ and is not charged.
    #
    # The request uses the client's ordinary +timeout+ (30 seconds by default), not +capture_timeout+, since
    # nothing runs while it waits.
    #
    # @example
    #   queued = client.instant_snap.submit(url: "https://example.com", timeout: 240)
    #   capture = client.instant_snap.wait(queued)
    #
    # @param url [String] the page to capture, absolute http or https
    # @param timeout [Integer, nil] seconds of browser time the capture may use, 30 to 300; the server uses
    #   120 when it is left out
    # @param idempotency_key [String, nil] makes the call safe to repeat; a random one is used otherwise
    # @param options [Hash] any of {CAPTURE_OPTIONS}, as for {#capture}
    # @option (see #capture)
    # @return [Capture] with status +queued+
    # @raise [RateLimitError] +queue_full+ when the organization already has as many async captures waiting or
    #   running as it may; not retried, see {Error#retry_after_seconds}
    # @raise [Error] a subclass matching any other refusal
    def submit(url:, timeout: nil, idempotency_key: nil, **options)
      options = options.merge(timeout: timeout)
      hash, response = post_capture(ResponseType::JSON, url, options, idempotency_key, @timeout, async: true)
      Capture.from_api(hash, idempotent_replayed: replayed?(response))
    end

    # Submits an async capture whose file is uploaded to your S3-compatible bucket, and answers at once with
    # the capture in status +queued+. Otherwise as {#submit}.
    #
    # @param s3_delivery [Hash] as for {#capture_to_bucket}
    # @param (see #submit)
    # @option (see #capture)
    # @return [Capture] with status +queued+
    # @raise (see #submit)
    def submit_to_bucket(url:, s3_delivery:, timeout: nil, idempotency_key: nil, **options)
      options = options.merge(s3_delivery: s3_delivery, timeout: timeout)
      hash, response = post_capture(ResponseType::CLOUD_STORAGE, url, options, idempotency_key, @timeout,
                                    async: true)
      Capture.from_api(hash, idempotent_replayed: replayed?(response))
    end

    # Reads a capture with {#get} every +poll_interval_seconds+ until its status is no longer +queued+,
    # +running+ or +pending+, and returns it.
    #
    # When +timeout_seconds+ runs out first, returns the capture as last read, still unfinished, rather than
    # raising, so you can decide whether to wait again. A refusal from {#get} is raised as from {#get}.
    #
    # @param capture [Capture, String] the capture, or its id
    # @param timeout_seconds [Numeric] how long to keep polling
    # @param poll_interval_seconds [Numeric] the pause between reads; 0 does not pause
    # @return [Capture]
    # @raise [Error] a subclass matching a refusal of {#get}
    def wait(capture, timeout_seconds: 360, poll_interval_seconds: 3)
      id = capture.respond_to?(:id) ? capture.id : capture
      deadline = clock + timeout_seconds
      loop do
        current = get(id)
        remaining = deadline - clock
        return current if !UNFINISHED.include?(current.status) || remaining <= 0

        sleep([poll_interval_seconds, remaining].min) if poll_interval_seconds.positive?
      end
    end

    # Reads a capture back. This also reissues its +download_url+.
    #
    # @param id [String]
    # @return [Capture]
    # @raise [NotFoundError] when there is no such capture for this account
    def get(id)
      hash, = request_json(:get, "/instant-snap/v1/captures/#{path_segment(id)}")
      Capture.from_api(hash)
    end

    # Downloads a capture's file (or its page source) from its +download_url+, without holding it in
    # memory. The API key is not sent to the download host.
    #
    # @param capture [Capture, PageSource, String] anything with a +download_url+, or the URL itself
    # @param target [String, Pathname, #write] a path to create or overwrite, or an open IO
    # @param timeout [Numeric, nil] seconds for the whole download; defaults to the client's +capture_timeout+
    # @return [String, Pathname, #write] +target+
    # @raise [ArgumentError] when the capture has no +download_url+
    def download(capture, target, timeout: nil)
      url = capture.respond_to?(:download_url) ? capture.download_url : capture
      raise ArgumentError, "this capture has no download_url; read it again with #get to reissue one" unless url

      @transport.request(:get, url, headers: { "Accept" => "*/*" }, timeout: timeout || @capture_timeout) do |answer|
        Transport.write_body(answer, target)
      end
      target
    end

    # The values a capture takes for options it does not send, and the limits it is checked against.
    # Needs no API key.
    #
    # @return [Defaults]
    def defaults
      hash, = request_json(:get, "/instant-snap/v1/defaults", authenticate: false)
      Defaults.from_api(hash)
    end

    # The devices +emulated_device+ accepts and the countries +proxy: { country: }+ accepts.
    #
    # @return [Catalog]
    def catalog
      hash, = request_json(:get, "/instant-snap/v1/catalog")
      Catalog.from_api(hash)
    end

    private

    def post_capture(response_type, url, options, idempotency_key, timeout, async: false)
      request_json(:post, CAPTURES_PATH,
                   body: capture_body(response_type, url, options, async: async),
                   headers: capture_headers(idempotency_key),
                   timeout: timeout || @capture_timeout)
    end

    def capture_body(response_type, url, options, async: false)
      unknown = options.keys - CAPTURE_OPTIONS
      unless unknown.empty?
        raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}"
      end

      body = without_nils(url: url, **options).merge(response_type: response_type)
      async ? body.merge(async: true) : body
    end

    # One key per call, reused by that call's retries, so a retry never captures twice.
    def capture_headers(idempotency_key)
      { "Idempotency-Key" => idempotency_key || SecureRandom.uuid }
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def replayed?(response)
      response["Idempotent-Replayed"] == "true"
    end
  end
end
