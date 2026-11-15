# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Whose API key this is, as returned by {InstantSnap#account} and {AutoSchedule#account}. It never
  # includes the key itself.
  #
  # @!attribute [r] key_name
  #   @return [String, nil] the name given to the key in the dashboard (Developer Tools, API Keys)
  # @!attribute [r] key_prefix
  #   @return [String] the key's public prefix, as the dashboard shows it; not enough to use the key
  # @!attribute [r] product
  #   @return [String] one of {Product}
  # @!attribute [r] email
  #   @return [String, nil] the member who created the key; nil when they are no longer a member
  Account = Data.define(:key_name, :key_prefix, :product, :email) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash)
    end
  end
end
