# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Render links: signed URLs of an Instant Snap key that are themselves a screenshot.
  #
  # @example
  #   src = WebsiteScreenshotWorld::RenderLink.build(
  #     render_secret: ENV.fetch("WSW_RENDER_SECRET"), key_prefix: "0123456789ab",
  #     url: "https://example.com", format: "webp", width: 1280, thumb_width: 400
  #   )
  module RenderLink
    PATH_PREFIX = "/instant-snap/v1/render/"
    FORMATS = %w[png jpeg webp].freeze

    # The options a link may carry beside +url+, by their API names.
    OPTIONS = %i[
      ttl width height device_scale_factor device_category emulated_device scroll_mode auto_height max_height
      zoom block_ads block_pop_ups press_escape page_timeout_ms scrolling_delay_ms locale time_zone hide xpath
      click hover country thumb_width
    ].freeze

    class << self
      # Builds a render link: a URL that is itself a screenshot, for an +<img>+ tag, an email or a social
      # preview. It is made here, locally - nothing is sent, and no client or API key is needed. Every view of
      # the link that is not already cached makes one Instant Snap capture.
      #
      # @param render_secret [String] the key's render secret (+wsw_rsk_...+), shown on the API Keys page once
      #   render links are on for the key
      # @param key_prefix [String] the key's 12-character prefix: the part after +wsw_api_+ and before the next +_+
      # @param url [String] the page to capture
      # @param format [String] +png+ (the default), +jpeg+ or +webp+
      # @param base_url [String, nil] defaults to {Client::DEFAULT_INSTANT_SNAP_BASE_URL}
      # @param options [Hash] any of {OPTIONS}: +ttl+ (seconds a capture is served from cache, 3600 to 2592000),
      #   the viewport and capture settings by their API names, +hide+, +xpath+, +click+ and +hover+ (the
      #   capture's selectors), +country+ (its proxy country) and +thumb_width+. A +nil+ option is left out.
      # @return [String] the link
      # @raise [ArgumentError] when +render_secret+, +key_prefix+ or +url+ is empty, +key_prefix+ is not 12
      #   lower-case hex characters, +format+ is not png, jpeg or webp, or an option is not one of {OPTIONS}
      def build(render_secret:, key_prefix:, url:, format: "png", base_url: nil, **options)
        validate(render_secret, key_prefix, url, format, options)

        query = canonical_query({ url: url }.merge(options))
        canonical = "#{PATH_PREFIX}#{key_prefix}/#{format}?#{query}"
        signature = OpenSSL::HMAC.hexdigest("SHA256", render_secret, canonical)
        "#{(base_url || Client::DEFAULT_INSTANT_SNAP_BASE_URL).chomp("/")}#{canonical}&sig=#{signature}"
      end

      private

      def validate(render_secret, key_prefix, url, format, options)
        raise ArgumentError, "render_secret is required" if render_secret.to_s.empty?
        unless key_prefix.to_s.match?(/\A[0-9a-f]{12}\z/)
          raise ArgumentError, "key_prefix must be the key's 12-character prefix (lower-case hex)"
        end
        raise ArgumentError, "url is required" if url.to_s.empty?
        raise ArgumentError, "format must be png, jpeg or webp" unless FORMATS.include?(format.to_s)

        unknown = options.keys - OPTIONS
        raise ArgumentError, "unknown render link option: #{unknown.join(", ")}" unless unknown.empty?
      end

      def canonical_query(parameters)
        parameters
          .compact
          .map { |name, value| [encode(name.to_s), encode(wire_value(value))] }
          .sort_by(&:first)
          .map { |name, value| "#{name}=#{value}" }
          .join("&")
      end

      # Booleans as true/false, numbers in their shortest decimal form (2, 1.5), strings as given.
      def wire_value(value)
        return value.to_i.to_s if value.is_a?(Float) && value.finite? && value == value.to_i

        value.to_s
      end

      # RFC 3986: every UTF-8 byte but A-Z a-z 0-9 - . _ ~, upper-case hex.
      def encode(value)
        value.b.gsub(/[^A-Za-z0-9\-._~]/n) { |byte| format("%%%02X", byte.ord) }
      end
    end
  end
end
