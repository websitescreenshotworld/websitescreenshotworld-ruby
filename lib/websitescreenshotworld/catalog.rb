# frozen_string_literal: true

module WebsiteScreenshotWorld
  # What the +emulated_device+ and +proxy: { country: }+ options accept, as returned by
  # {InstantSnap#catalog}.
  #
  # @!attribute [r] emulated_devices
  #   @return [Array<String>]
  # @!attribute [r] proxy_countries
  #   @return [Array<String>]
  Catalog = Data.define(:emulated_devices, :proxy_countries) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash)
    end
  end
end
