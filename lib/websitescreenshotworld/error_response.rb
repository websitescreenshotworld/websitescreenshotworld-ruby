# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Turns a refusal into the matching {Error}, following the API's error table.
  #
  # @api private
  module ErrorResponse
    KINDS = {
      AuthenticationError => %w[api_key_invalid],
      InvalidRequestError => %w[
        validation_failed s3_destination_invalid web_page_id_invalid idempotency_key_reused
        sitemap_schedule_not_triggerable
      ],
      PlanLimitError => %w[quota_exhausted feature_not_available no_trigger_allowance forbidden],
      NotFoundError => %w[capture_not_found web_page_not_found not_found],
      RateLimitError => %w[rate_limited queue_full],
      CaptureError => %w[capture_failed capture_timeout payload_too_large capture_expired],
      ServiceError => %w[capture_busy service_unavailable internal_error request_cancelled idempotency_key_in_use]
    }.flat_map { |klass, codes| codes.map { |code| [code, klass] } }.to_h.freeze

    RETRYABLE = %w[rate_limited capture_busy service_unavailable idempotency_key_in_use].freeze

    # A proxy or load balancer answers without the API's JSON body; the code then comes from the status.
    FALLBACK_BY_STATUS = {
      400 => "validation_failed",
      401 => "api_key_invalid",
      403 => "forbidden",
      404 => "not_found",
      409 => "idempotency_key_in_use",
      413 => "payload_too_large",
      429 => "rate_limited",
      500 => "internal_error",
      502 => "service_unavailable",
      503 => "service_unavailable",
      504 => "service_unavailable"
    }.freeze

    module_function

    # @param response [Net::HTTPResponse]
    # @return [Error]
    def build(response)
      status = response.code.to_i
      body = response.body
      refusal = parse(body)
      code = refusal&.fetch("error_code") || FALLBACK_BY_STATUS.fetch(status, "unknown_error")
      message = refusal&.dig("error_message") || "The server answered HTTP #{status} without an error body."
      retry_after = refusal&.dig("retry_after_seconds")
      retry_after = retry_after_header(response["Retry-After"]) unless retry_after.is_a?(Numeric)

      KINDS.fetch(code, Error).new(
        message, error_code: code, http_status: status, retry_after_seconds: retry_after, body: body
      )
    end

    # @param error_code [String, nil]
    def retryable?(error_code)
      RETRYABLE.include?(error_code)
    end

    def parse(body)
      refusal = Model.parse_json(body.to_s)
      refusal if refusal.is_a?(Hash) && refusal["error_code"].is_a?(String)
    rescue JSON::ParserError
      nil
    end

    def retry_after_header(value)
      return if value.nil?

      Integer(value, exception: false) || [(Time.httpdate(value) - Time.now).ceil, 0].max
    rescue ArgumentError
      nil
    end
  end
end
