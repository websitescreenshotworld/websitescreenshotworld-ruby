# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Verifies webhook deliveries from both products.
  #
  # @example
  #   event = WebsiteScreenshotWorld::Webhook.verify(
  #     request.raw_post, request.headers["X-WSW-Signature"], ENV.fetch("WSW_WEBHOOK_SECRET")
  #   )
  module Webhook
    # The header that carries the signature.
    SIGNATURE_HEADER = "X-WSW-Signature"

    # Seconds a delivery's timestamp may differ from the current time.
    DEFAULT_TOLERANCE = 300

    class << self
      # Checks a delivery's signature and returns its event.
      #
      # @param payload [String] the request body exactly as received, not parsed and re-serialised
      # @param signature_header [String, nil] the value of the +X-WSW-Signature+ header
      # @param secret [String] the endpoint's signing secret
      # @param tolerance [Integer] seconds the signed timestamp may be before or after +now+
      # @param now [Time] the current time
      # @return [Event] a subclass matching the event's type, or {UnknownEvent}
      # @raise [SignatureVerificationError] when the header is missing or malformed, the timestamp is outside
      #   the tolerance, or no signature matches
      # @raise [ArgumentError] when +payload+ is not a String or +secret+ is empty
      def verify(payload, signature_header, secret, tolerance: DEFAULT_TOLERANCE, now: Time.now)
        raise ArgumentError, "payload must be the raw request body as a String" unless payload.is_a?(String)
        raise ArgumentError, "secret must not be empty" if secret.to_s.empty?

        timestamp, signatures = parse_header(signature_header.to_s)
        if (now.to_i - timestamp).abs > tolerance
          raise SignatureVerificationError, "The signature's timestamp is outside the #{tolerance}-second tolerance."
        end

        expected = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s.b, "#{timestamp}.".b + payload.b)
        unless signatures.any? { |signature| OpenSSL.secure_compare(expected, signature.downcase) }
          raise SignatureVerificationError, "No signature in the #{SIGNATURE_HEADER} header matches the payload."
        end

        Event.from_api(Model.parse_json(payload))
      end

      private

      def parse_header(header)
        pairs = header.split(",").map { |part| part.split("=", 2).map(&:strip) }
        [timestamp_from(pairs), signatures_from(pairs)]
      end

      def timestamp_from(pairs)
        value = pairs.find { |name, _| name == "t" }&.last
        return Integer(value, 10) if value&.match?(/\A\d+\z/)

        raise SignatureVerificationError, "The #{SIGNATURE_HEADER} header has no valid timestamp."
      end

      def signatures_from(pairs)
        signatures = pairs.filter_map { |name, value| value if name == "v1" }
        return signatures unless signatures.empty?

        raise SignatureVerificationError, "The #{SIGNATURE_HEADER} header has no v1 signature."
      end
    end
  end
end
