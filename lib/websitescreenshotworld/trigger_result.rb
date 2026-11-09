# frozen_string_literal: true

module WebsiteScreenshotWorld
  # The answer to {AutoSchedule#trigger_now}. The capture itself arrives later by webhook.
  #
  # @!attribute [r] status
  #   @return [String] one of {TriggerStatus}
  # @!attribute [r] web_page_id
  #   @return [String]
  # @!attribute [r] triggered_by
  #   @return [String] one of {TriggeredBy}
  # @!attribute [r] triggered_at
  #   @return [Time] when the capture was queued; for +already_pending+, the original trigger
  # @!attribute [r] message
  #   @return [String] one sentence for a person
  TriggerResult = Data.define(:status, :web_page_id, :triggered_by, :triggered_at, :message) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, triggered_at: Model.time(hash["triggered_at"]))
    end
  end
end
