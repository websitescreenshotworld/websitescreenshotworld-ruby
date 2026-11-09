# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Base class of every error the library raises. Rescue a subclass to handle one kind of refusal, and
  # switch on {#error_code} rather than on the status or the message.
  class Error < StandardError
    # @return [String, nil] the API's stable error token, such as +"rate_limited"+
    attr_reader :error_code

    # @return [Integer, nil] the HTTP status of the refusal
    attr_reader :http_status

    # @return [Integer, nil] how long the API asked to wait before retrying
    attr_reader :retry_after_seconds

    # @return [String, nil] the response body exactly as received
    attr_reader :body

    # @param message [String]
    # @param error_code [String, nil]
    # @param http_status [Integer, nil]
    # @param retry_after_seconds [Integer, nil]
    # @param body [String, nil]
    def initialize(message = nil, error_code: nil, http_status: nil, retry_after_seconds: nil, body: nil)
      super(message)
      @error_code = error_code
      @http_status = http_status
      @retry_after_seconds = retry_after_seconds
      @body = body
    end
  end

  # The API key is missing, malformed, revoked or belongs to the other product.
  class AuthenticationError < Error; end

  # The request was refused as invalid, for example a +validation_failed+ or +idempotency_key_reused+.
  class InvalidRequestError < Error; end

  # The plan has no captures left or does not include the feature.
  class PlanLimitError < Error; end

  # The capture or web page does not exist for this account.
  class NotFoundError < Error; end

  # Too many requests. +rate_limited+ is retried automatically before it is raised. +queue_full+ (as many
  # async captures waiting or running as the organization may have) is not retried; wait
  # {#retry_after_seconds} before submitting again.
  class RateLimitError < Error; end

  # The website could not be captured (+capture_failed+, +capture_timeout+, +payload_too_large+), or an async
  # capture waited too long in the queue (+capture_expired+). Not retried.
  class CaptureError < Error; end

  # The service is busy or unavailable. The retryable codes are retried automatically before it is raised.
  class ServiceError < Error; end

  # No answer came back: the connection failed, broke, or the timeout ran out. The original exception is
  # available as +cause+.
  class ConnectionError < Error; end

  # A webhook's +X-WSW-Signature+ header is missing, malformed, too old, or does not match the body.
  class SignatureVerificationError < Error; end
end
