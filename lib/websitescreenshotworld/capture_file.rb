# frozen_string_literal: true

module WebsiteScreenshotWorld
  # The file a +by_format+ capture answers with, and its metadata. The body is read once: call {#save},
  # {#read} or {#each_chunk}.
  #
  # Inside the block given to {InstantSnap#capture_file} the body streams from the connection. Without a
  # block it is first buffered to a +Tempfile+, which {#close} deletes.
  class CaptureFile
    CHUNK_SIZE = 64 * 1024
    private_constant :CHUNK_SIZE

    # @return [String, nil] the capture id
    attr_reader :id

    # @return [String, nil] +delivered+
    attr_reader :status

    # @return [String, nil] the file's media type, such as +image/png+
    attr_reader :content_type

    # @return [String, nil] the file name from +Content-Disposition+
    attr_reader :filename

    # @return [Integer, nil]
    attr_reader :width

    # @return [Integer, nil]
    attr_reader :height

    # @return [Integer, nil]
    attr_reader :size_bytes

    # @return [Integer, nil] how long the capture took
    attr_reader :duration_ms

    # @return [Integer, nil] the status the website answered with
    attr_reader :page_http_status

    # @return [String, nil] the default set the capture was taken under
    attr_reader :spec_version

    # @return [Time, nil]
    attr_reader :captured_at

    # @return [String, nil] where the browser ended up; absent when that URL is not plain ASCII
    attr_reader :final_url

    # @return [String, nil] lowercase hex digest of the file
    attr_reader :sha256

    # @return [Integer, nil] the number of parts, only when the answer has more than one
    attr_reader :part_count

    # @api private
    def self.buffered(response)
      tempfile = Tempfile.new("websitescreenshotworld", binmode: true)
      Transport.each_chunk(response) { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      new(response, tempfile: tempfile)
    rescue StandardError
      tempfile&.close!
      raise
    end

    # @api private
    def initialize(response, tempfile: nil)
      @response = response
      @tempfile = tempfile
      @consumed = false
      read_metadata(response)
    end

    # Yields the file in chunks as they arrive.
    #
    # @yieldparam chunk [String] binary bytes
    # @return [Enumerator, nil] an enumerator when no block is given
    # @raise [IOError] when the body has already been read
    # @raise [ConnectionError] when the connection breaks mid-file
    def each_chunk(&block)
      return enum_for(:each_chunk) unless block
      raise IOError, "the capture file has already been read" if @consumed

      @consumed = true
      if @tempfile
        while (chunk = @tempfile.read(CHUNK_SIZE))
          yield chunk
        end
      else
        Transport.each_chunk(@response, &block)
      end
      nil
    end

    # Reads the whole file into memory.
    #
    # @return [String] binary bytes
    def read
      buffer = String.new(encoding: Encoding::BINARY)
      each_chunk { |chunk| buffer << chunk }
      buffer
    end

    # Writes the file to a path or an IO without holding it in memory.
    #
    # @param target [String, Pathname, #write] a path to create or overwrite, or an open IO
    # @return [String, Pathname, #write] +target+
    def save(target)
      if target.respond_to?(:write)
        each_chunk { |chunk| target.write(chunk) }
      else
        File.open(target, "wb") { |file| each_chunk { |chunk| file.write(chunk) } }
      end
      target
    end

    # @return [String, nil] the path of the buffered copy, when the file was captured without a block
    def path
      @tempfile&.path
    end

    # Deletes the buffered copy, if any.
    #
    # @return [void]
    def close
      @tempfile&.close!
    end

    private

    def read_metadata(response)
      header = ->(name) { response["X-InstantSnap-#{name}"] }
      @id = header["Id"]
      @status = header["Status"]
      @content_type = response["Content-Type"]
      @filename = self.class.filename_from(response["Content-Disposition"])
      @width, @height, @size_bytes, @duration_ms, @page_http_status, @part_count =
        %w[Width Height Size-Bytes Duration-Ms Page-Http-Status Part-Count].map { integer(header[_1]) }
      @spec_version = header["Spec-Version"]
      @captured_at = Model.time(header["Captured-At"])
      @final_url = header["Final-Url"]
      @sha256 = header["Sha256"]
    end

    def integer(value)
      value && Integer(value, 10, exception: false)
    end

    class << self
      # @api private
      def filename_from(disposition)
        return if disposition.nil?

        name =
          if (encoded = disposition[/filename\*\s*=\s*UTF-8''([^;\s]+)/i, 1])
            URI.decode_uri_component(encoded)
          elsif (quoted = disposition[/filename\s*=\s*"((?:\\.|[^"\\])*)"/i, 1])
            quoted.gsub(/\\(.)/, '\1')
          else
            disposition[/filename\s*=\s*([^;\s]+)/i, 1]
          end
        # The name is the server's suggestion; never let it point outside the caller's directory.
        name && File.basename(name)
      end
    end
  end
end
