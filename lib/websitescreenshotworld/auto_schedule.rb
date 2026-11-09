# frozen_string_literal: true

module WebsiteScreenshotWorld
  # The Auto Schedule API: start a scheduled web page's capture now. Reach it through
  # {Client#auto_schedule}. The capture's result arrives by webhook.
  class AutoSchedule < Service
    MISSING_KEY = "No Auto Schedule API key was given: pass auto_schedule_api_key: to " \
                  "WebsiteScreenshotWorld::Client.new or set WSW_AUTO_SCHEDULE_API_KEY."

    # Queues a capture of a web page set up in the dashboard. Safe to repeat: while a capture is pending,
    # another call answers +already_pending+ and charges nothing.
    #
    # @param web_page_id [String] the web page's id, the same id webhooks call +schedule_id+
    # @return [TriggerResult]
    # @raise [NotFoundError] when there is no such web page for this account
    # @raise [Error] another subclass matching the refusal
    def trigger_now(web_page_id)
      hash, = request_json(:post, "/auto-schedule/v1/web-pages/#{path_segment(web_page_id)}/trigger-now")
      TriggerResult.from_api(hash)
    end
  end
end
