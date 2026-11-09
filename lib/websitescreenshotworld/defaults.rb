# frozen_string_literal: true

module WebsiteScreenshotWorld
  # A viewport in CSS pixels.
  #
  # @!attribute [r] width
  #   @return [Integer]
  # @!attribute [r] height
  #   @return [Integer]
  # @!attribute [r] device_scale_factor
  #   @return [Numeric] device pixel ratio
  Viewport = Data.define(:width, :height, :device_scale_factor) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash)
    end
  end

  # The values a capture takes for options it does not send, and the limits it is checked against,
  # as returned by {InstantSnap#defaults}. Fields the server leaves out are nil.
  #
  # @!attribute [r] spec_version
  #   @return [String]
  # @!attribute [r] response_type
  #   @return [String]
  # @!attribute [r] media_category
  #   @return [String]
  # @!attribute [r] format
  #   @return [Hash{String => String}, nil] the default format of each media category
  # @!attribute [r] formats
  #   @return [Hash{String => Array<String>}, nil] the formats each media category accepts
  # @!attribute [r] device_category
  #   @return [String, nil]
  # @!attribute [r] emulated_device
  #   @return [String, nil]
  # @!attribute [r] viewport
  #   @return [Viewport, nil]
  # @!attribute [r] zoom
  #   @return [Integer, nil]
  # @!attribute [r] scroll_mode
  #   @return [String, nil]
  # @!attribute [r] auto_height
  #   @return [Boolean, nil]
  # @!attribute [r] auto_height_max_height
  #   @return [Integer, nil]
  # @!attribute [r] auto_height_max_height_webp
  #   @return [Integer, nil]
  # @!attribute [r] block_ads
  #   @return [Boolean, nil]
  # @!attribute [r] block_pop_ups
  #   @return [Boolean, nil]
  # @!attribute [r] press_escape
  #   @return [Boolean, nil]
  # @!attribute [r] page_timeout_ms
  #   @return [Integer, nil]
  # @!attribute [r] scrolling_delay_ms
  #   @return [Integer, nil]
  # @!attribute [r] geolocation
  #   @return [Boolean, nil]
  # @!attribute [r] geolocation_accuracy
  #   @return [Numeric, nil]
  # @!attribute [r] wait_for_cloud_sync
  #   @return [Boolean, nil]
  # @!attribute [r] timestamp_watermark
  #   @return [Hash, nil]
  # @!attribute [r] page_source
  #   @return [Hash, nil]
  # @!attribute [r] limits
  #   @return [Hash, nil]
  # @!attribute [r] left_to_the_browser
  #   @return [Array<String>, nil]
  Defaults = Data.define(
    :spec_version, :response_type, :media_category, :format, :formats, :device_category, :emulated_device,
    :viewport, :zoom, :scroll_mode, :auto_height, :auto_height_max_height, :auto_height_max_height_webp,
    :block_ads, :block_pop_ups, :press_escape, :page_timeout_ms, :scrolling_delay_ms, :geolocation,
    :geolocation_accuracy, :wait_for_cloud_sync, :timestamp_watermark, :page_source, :limits, :left_to_the_browser
  ) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, viewport: hash["viewport"]&.then { Viewport.from_api(_1) })
    end
  end
end
