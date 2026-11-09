# frozen_string_literal: true

module WebsiteScreenshotWorld
  # One client covers both products. Either key may be left out; calling a product whose key is missing
  # raises {AuthenticationError} before anything is sent. A client holds no connection and can be shared
  # between threads.
  #
  # @example
  #   client = WebsiteScreenshotWorld::Client.new
  #   client.instant_snap.capture(url: "https://example.com")
  #   client.auto_schedule.trigger_now("7d4e2b1a-6c5f-4a3e-9d8c-2b1a0f9e8d7c")
  class Client
    DEFAULT_INSTANT_SNAP_BASE_URL = "https://api.websitescreenshotworld.com"
    DEFAULT_AUTO_SCHEDULE_BASE_URL = "https://autoapi.websitescreenshotworld.com"

    # @return [InstantSnap]
    attr_reader :instant_snap

    # @return [AutoSchedule]
    attr_reader :auto_schedule

    # @param instant_snap_api_key [String, nil] defaults to +ENV["WSW_INSTANT_SNAP_API_KEY"]+
    # @param auto_schedule_api_key [String, nil] defaults to +ENV["WSW_AUTO_SCHEDULE_API_KEY"]+
    # @param instant_snap_base_url [String]
    # @param auto_schedule_base_url [String]
    # @param capture_timeout [Numeric] seconds a capture or download may take, retries included; the
    #   server may spend up to 120 seconds on a capture
    # @param timeout [Numeric] seconds any other call may take, retries included
    # @param max_retries [Integer] retries after the first attempt for refusals the API marks as
    #   retryable and for connection failures; 0 turns retrying off
    def initialize(
      instant_snap_api_key: ENV.fetch("WSW_INSTANT_SNAP_API_KEY", nil),
      auto_schedule_api_key: ENV.fetch("WSW_AUTO_SCHEDULE_API_KEY", nil),
      instant_snap_base_url: DEFAULT_INSTANT_SNAP_BASE_URL,
      auto_schedule_base_url: DEFAULT_AUTO_SCHEDULE_BASE_URL,
      capture_timeout: 180,
      timeout: 30,
      max_retries: 2
    )
      transport = Transport.new(max_retries: max_retries)
      @instant_snap = InstantSnap.new(transport: transport, base_url: instant_snap_base_url,
                                      api_key: instant_snap_api_key, timeout: timeout,
                                      capture_timeout: capture_timeout)
      @auto_schedule = AutoSchedule.new(transport: transport, base_url: auto_schedule_base_url,
                                        api_key: auto_schedule_api_key, timeout: timeout)
    end
  end
end
