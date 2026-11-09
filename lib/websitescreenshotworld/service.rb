# frozen_string_literal: true

module WebsiteScreenshotWorld
  # What {InstantSnap} and {AutoSchedule} share: the key, the base URL and JSON requests.
  #
  # @api private
  class Service
    def initialize(transport:, base_url:, api_key:, timeout:)
      @transport = transport
      @base_url = base_url.to_s.chomp("/")
      @api_key = api_key.to_s.empty? ? nil : api_key
      @timeout = timeout
    end

    # Keeps the API key out of logs and consoles.
    def inspect
      "#<#{self.class.name} base_url=#{@base_url.inspect}>"
    end

    private

    # Sends a call to this product and yields the successful response with its body unread.
    def send_request(method, path, body: nil, headers: {}, timeout: @timeout, authenticate: true,
                     accept: "application/json", &)
      headers = { "Accept" => accept }.merge(headers)
      headers["Content-Type"] = "application/json" if body
      headers["X-Api-Key"] = api_key! if authenticate
      @transport.request(method, "#{@base_url}#{path}", headers: headers, body: body && JSON.generate(body),
                                                        timeout: timeout, &)
    end

    # @return [Array(Hash, Net::HTTPResponse)] the answer without +success+, and the response for its headers
    def request_json(method, path, **options)
      response = send_request(method, path, **options) { |answer| answer.tap(&:read_body) }
      [parse(response), response]
    end

    def api_key!
      @api_key || raise(AuthenticationError, self.class::MISSING_KEY)
    end

    def parse(response)
      hash = Model.parse_json(response.body)
      raise JSON::ParserError, "expected an object" unless hash.is_a?(Hash)

      hash.except("success").freeze
    rescue JSON::ParserError
      raise Error.new("The server answered HTTP #{response.code} with a body that is not a JSON object.",
                      http_status: response.code.to_i, body: response.body)
    end

    def path_segment(value)
      URI.encode_uri_component(value.to_s)
    end

    # Drops the options that were not set, at every level; +false+, +0+ and +""+ stay.
    def without_nils(hash)
      hash.each_with_object({}) do |(key, value), result|
        next if value.nil?

        result[key] = value.is_a?(Hash) ? without_nils(value) : value
      end
    end
  end
end
