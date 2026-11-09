# frozen_string_literal: true

module WebsiteScreenshotWorld
  # The page source kept alongside a capture when +page_source:+ was requested.
  #
  # @!attribute [r] format
  #   @return [String] one of {PageSourceFormat}
  # @!attribute [r] content_type
  #   @return [String, nil]
  # @!attribute [r] size_bytes
  #   @return [Integer, nil]
  # @!attribute [r] sha256
  #   @return [String, nil] lowercase hex digest of the source
  # @!attribute [r] download_url
  #   @return [String, nil] short-lived link, reissued on every read; pass the object to
  #     {InstantSnap#download} to fetch it
  PageSource = Data.define(:format, :content_type, :size_bytes, :sha256, :download_url) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash)
    end
  end

  # Where a +cloud_storage+ capture was uploaded.
  #
  # @!attribute [r] status
  #   @return [String] one of {S3DeliveryStatus}
  # @!attribute [r] bucket
  #   @return [String]
  # @!attribute [r] key
  #   @return [String, nil] the object key, once known
  # @!attribute [r] access_key_id
  #   @return [String, nil] masked to its last four characters
  # @!attribute [r] error
  #   @return [String, nil] why the upload failed
  S3Delivery = Data.define(:status, :bucket, :key, :access_key_id, :error) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash)
    end
  end

  # An Instant Snap capture, as returned by {InstantSnap#capture}, {InstantSnap#capture_to_bucket},
  # {InstantSnap#submit}, {InstantSnap#submit_to_bucket}, {InstantSnap#wait}, {InstantSnap#get} and the
  # Instant Snap webhooks.
  #
  # @!attribute [r] id
  #   @return [String]
  # @!attribute [r] status
  #   @return [String] one of {CaptureStatus}; an async capture is +queued+, then +running+, then
  #     +succeeded+ or +failed+, and its file fields are nil until it has finished
  # @!attribute [r] response_type
  #   @return [String] one of {ResponseType}
  # @!attribute [r] media_category
  #   @return [String, nil] one of {MediaCategory}; nil while an async capture is unfinished
  # @!attribute [r] format
  #   @return [String, nil] the format written, one of {Format}
  # @!attribute [r] content_type
  #   @return [String, nil]
  # @!attribute [r] size_bytes
  #   @return [Integer, nil]
  # @!attribute [r] width
  #   @return [Integer, nil]
  # @!attribute [r] height
  #   @return [Integer, nil]
  # @!attribute [r] duration_ms
  #   @return [Integer, nil] how long the capture took
  # @!attribute [r] page_http_status
  #   @return [Integer, nil] the status the website answered with
  # @!attribute [r] captured_at
  #   @return [Time, nil]
  # @!attribute [r] final_url
  #   @return [String, nil] where the browser ended up, when the page redirected
  # @!attribute [r] media_sha256
  #   @return [String, nil] lowercase hex digest of the file
  # @!attribute [r] download_url
  #   @return [String, nil] valid for 60 minutes and reissued by {InstantSnap#get}; nil for +by_format+,
  #     +cloud_storage+ and webhooks
  # @!attribute [r] expires_at
  #   @return [Time, nil] when the file is deleted
  # @!attribute [r] page_source
  #   @return [PageSource, nil]
  # @!attribute [r] s3_delivery
  #   @return [S3Delivery, nil] present for +cloud_storage+ only
  # @!attribute [r] callback_url
  #   @return [String, nil]
  # @!attribute [r] error_code
  #   @return [String, nil] why a +failed+ or +timed_out+ capture ended
  # @!attribute [r] spec_version
  #   @return [String] the default set the capture was taken under
  Capture = Data.define(
    :id, :status, :response_type, :media_category, :format, :content_type, :size_bytes, :width, :height,
    :duration_ms, :page_http_status, :captured_at, :final_url, :media_sha256, :download_url, :expires_at,
    :page_source, :s3_delivery, :callback_url, :error_code, :spec_version
  ) do
    include Model::Raw

    def initialize(idempotent_replayed: false, **fields)
      @idempotent_replayed = idempotent_replayed
      super(**fields)
    end

    # @return [Boolean] whether this answer replays an earlier request made with the same idempotency key
    def idempotent_replayed?
      @idempotent_replayed
    end

    # @api private
    def self.from_api(hash, idempotent_replayed: false)
      Model.build(
        self, hash,
        idempotent_replayed: idempotent_replayed,
        captured_at: Model.time(hash["captured_at"]),
        expires_at: Model.time(hash["expires_at"]),
        page_source: hash["page_source"]&.then { PageSource.from_api(_1) },
        s3_delivery: hash["s3_delivery"]&.then { S3Delivery.from_api(_1) }
      )
    end
  end
end
