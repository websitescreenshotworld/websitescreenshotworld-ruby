# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Sends one call over Net::HTTP, retrying what the API marks as retryable.
  #
  # @api private
  class Transport
    USER_AGENT = "websitescreenshotworld-ruby/#{VERSION} (#{RUBY_ENGINE} #{RUBY_ENGINE_VERSION})".freeze

    CONNECTION_ERRORS = [
      IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse, Net::ProtocolError
    ].freeze

    MAX_RETRY_AFTER = 60
    FIRST_BACKOFF = 0.5
    JITTER = 0.25

    # Net::HTTP gives every POST a form Content-Type, even an empty one. Trigger-now has no body at all.
    class EmptyPost < Net::HTTPRequest
      METHOD = "POST"
      REQUEST_HAS_BODY = false
      RESPONSE_HAS_BODY = true
    end

    # Reads a response body chunk by chunk. A network failure becomes a {ConnectionError}; an exception
    # raised by the block passes through untouched.
    def self.each_chunk(response)
      in_block = false
      response.read_body do |chunk|
        in_block = true
        yield chunk
        in_block = false
      end
    rescue *CONNECTION_ERRORS => e
      raise if in_block

      raise ConnectionError, "The connection broke before the whole body arrived (#{e.message})."
    end

    # Writes a response body to an IO, or to a file it creates at a path and deletes again if the body does
    # not arrive whole.
    def self.write_body(response, target)
      return each_chunk(response) { |chunk| target.write(chunk) } if target.respond_to?(:write)

      File.open(target, "wb") { |file| each_chunk(response) { |chunk| file.write(chunk) } }
    rescue StandardError
      File.delete(target) if !target.respond_to?(:write) && File.exist?(target)
      raise
    end

    def initialize(max_retries:)
      @max_retries = max_retries
    end

    # Sends the request, retrying refusals and connection failures until it succeeds, the retries run out
    # or +timeout+ seconds have passed, then yields the successful response with its body still unread.
    #
    # @return the block's value
    def request(method, url, headers:, timeout:, body: nil)
      uri = URI(url)
      deadline = clock + timeout
      retries = 0
      delivered = false
      begin
        connection(uri, deadline).start do |http|
          http.request(build_request(method, uri, headers, body)) do |response|
            raise ErrorResponse.build(response) unless response.is_a?(Net::HTTPSuccess)

            delivered = true
            # Returning from inside the block closes the connection instead of draining an unread body.
            return yield(response)
          end
        end
      rescue Error, *CONNECTION_ERRORS => e
        raise if delivered

        error = e.is_a?(Error) ? e : ConnectionError.new("The request to #{uri.host} failed: #{e.message}")
        delay = retry_delay(error, retries, deadline) or raise error
        sleep(delay)
        retries += 1
        retry
      end
    end

    private

    def connection(uri, deadline)
      remaining = deadline - clock
      Net::HTTP.new(uri.hostname, uri.port).tap do |http|
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = http.read_timeout = http.write_timeout = http.ssl_timeout = remaining
        http.max_retries = 0
      end
    end

    def build_request(method, uri, headers, body)
      headers = headers.merge("User-Agent" => USER_AGENT)
      case [method, body.nil?]
      in [:get, _] then Net::HTTP::Get.new(uri, headers)
      in [:post, true] then EmptyPost.new(uri, headers.merge("Content-Length" => "0"))
      in [:post, false] then Net::HTTP::Post.new(uri, headers).tap { _1.body = body }
      end
    end

    # @return [Float, nil] seconds to wait before retrying, or nil to raise the error now
    def retry_delay(error, retries, deadline)
      return if retries >= @max_retries
      return unless error.is_a?(ConnectionError) || ErrorResponse.retryable?(error.error_code)

      delay = error.retry_after_seconds&.clamp(0, MAX_RETRY_AFTER) || backoff(retries)
      delay if clock + delay < deadline
    end

    def backoff(retries)
      base = FIRST_BACKOFF * (2**retries)
      base + (base * JITTER * rand)
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
