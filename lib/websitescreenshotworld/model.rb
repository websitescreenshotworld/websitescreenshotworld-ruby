# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Helpers the result types share.
  #
  # @api private
  module Model
    # Gives a +Data+ class a {#raw} reader holding the object as the API sent it.
    module Raw
      # @return [Hash{String => Object}] the object as the API sent it, including fields this version of the
      #   library does not know yet
      attr_reader :raw

      def initialize(raw: {}.freeze, **fields)
        @raw = raw
        super(**fields)
      end
    end

    module_function

    # Builds +klass+ from an API hash, taking each member from the key of the same name. Keys the class
    # does not know are left in +raw+ only; +converted+ replaces members that need more than a copy.
    def build(klass, hash, **converted)
      fields = klass.members.to_h { |name| [name, hash[name.to_s]] }
      klass.new(raw: hash, **fields, **converted)
    end

    # Parses a JSON body into frozen objects. The API always sends UTF-8, whatever encoding Ruby tagged the
    # bytes with.
    def parse_json(bytes)
      JSON.parse(String.new(bytes, encoding: Encoding::UTF_8), freeze: true)
    end

    # Parses an ISO 8601 timestamp (any fraction length, +Z+ or an offset) into a UTC +Time+.
    #
    # @return [Time, nil] nil when the value is absent or not a timestamp
    def time(value)
      return value if value.nil? || value.is_a?(Time)

      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end
  end
end
