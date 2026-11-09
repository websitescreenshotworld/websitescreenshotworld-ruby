# frozen_string_literal: true

module WebsiteScreenshotWorld
  # One destination of an Auto Schedule delivery, in a +delivery.completed+ event.
  #
  # @!attribute [r] slot
  #   @return [Integer]
  # @!attribute [r] name
  #   @return [String]
  # @!attribute [r] provider
  #   @return [String]
  # @!attribute [r] status
  #   @return [String]
  # @!attribute [r] completed_at
  #   @return [Time, nil]
  Destination = Data.define(:slot, :name, :provider, :status, :completed_at) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, completed_at: Model.time(hash["completed_at"]))
    end
  end

  # An Auto Schedule capture, the +data+ of its +capture.succeeded+, +capture.failed+,
  # +delivery.completed+ and +capture.changed+ events.
  #
  # @!attribute [r] id
  #   @return [String]
  # @!attribute [r] schedule_id
  #   @return [String] the web page's id, the one {AutoSchedule#trigger_now} takes
  # @!attribute [r] schedule_name
  #   @return [String]
  # @!attribute [r] url
  #   @return [String]
  # @!attribute [r] status
  #   @return [String]
  # @!attribute [r] media_category
  #   @return [String]
  # @!attribute [r] format
  #   @return [String, nil]
  # @!attribute [r] page_http_status
  #   @return [Integer, nil]
  # @!attribute [r] captured_at
  #   @return [Time, nil]
  # @!attribute [r] final_url
  #   @return [String, nil]
  # @!attribute [r] media_sha256
  #   @return [String, nil]
  # @!attribute [r] page_source
  #   @return [PageSource, nil] with +format+ and +sha256+ only
  # @!attribute [r] sitemap_run_id
  #   @return [String, nil]
  # @!attribute [r] destinations
  #   @return [Array<Destination>, nil] on +delivery.completed+ only
  # @!attribute [r] change_percent
  #   @return [Numeric, nil] on +capture.changed+ only
  # @!attribute [r] compared_to_capture_id
  #   @return [String, nil] on +capture.changed+ only
  # @!attribute [r] change_image_available
  #   @return [Boolean, nil] on +capture.changed+ only
  ScheduledCapture = Data.define(
    :id, :schedule_id, :schedule_name, :url, :status, :media_category, :format, :page_http_status,
    :captured_at, :final_url, :media_sha256, :page_source, :sitemap_run_id, :destinations, :change_percent,
    :compared_to_capture_id, :change_image_available
  ) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(
        self, hash,
        captured_at: Model.time(hash["captured_at"]),
        page_source: hash["page_source"]&.then { PageSource.from_api(_1) },
        destinations: hash["destinations"]&.map { Destination.from_api(_1) }
      )
    end
  end

  # The +data+ of a +schedule.paused+ event.
  #
  # @!attribute [r] schedule_id
  #   @return [String]
  # @!attribute [r] schedule_name
  #   @return [String]
  # @!attribute [r] url
  #   @return [String]
  # @!attribute [r] reason
  #   @return [String] such as +quota_exhausted+
  # @!attribute [r] paused_at
  #   @return [Time, nil]
  SchedulePause = Data.define(:schedule_id, :schedule_name, :url, :reason, :paused_at) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, paused_at: Model.time(hash["paused_at"]))
    end
  end

  # The +data+ of a +sitemap_run.completed+ event.
  #
  # @!attribute [r] sitemap_run_id
  #   @return [String]
  # @!attribute [r] schedule_id
  #   @return [String]
  # @!attribute [r] schedule_name
  #   @return [String]
  # @!attribute [r] sitemap_url
  #   @return [String]
  # @!attribute [r] status
  #   @return [String]
  # @!attribute [r] run_at
  #   @return [Time, nil]
  # @!attribute [r] completed_at
  #   @return [Time, nil]
  # @!attribute [r] pages_listed
  #   @return [Integer, nil]
  # @!attribute [r] pages_matched
  #   @return [Integer, nil]
  # @!attribute [r] pages_queued
  #   @return [Integer, nil]
  # @!attribute [r] pages_succeeded
  #   @return [Integer, nil]
  # @!attribute [r] pages_failed
  #   @return [Integer, nil]
  # @!attribute [r] pages_over_limit
  #   @return [Integer, nil]
  # @!attribute [r] pages_over_quota
  #   @return [Integer, nil]
  # @!attribute [r] message
  #   @return [String, nil]
  SitemapRun = Data.define(
    :sitemap_run_id, :schedule_id, :schedule_name, :sitemap_url, :status, :run_at, :completed_at,
    :pages_listed, :pages_matched, :pages_queued, :pages_succeeded, :pages_failed, :pages_over_limit,
    :pages_over_quota, :message
  ) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, run_at: Model.time(hash["run_at"]), completed_at: Model.time(hash["completed_at"]))
    end
  end

  # The +data+ of a +ping+ event, a test delivery to a webhook endpoint.
  #
  # @!attribute [r] endpoint_id
  #   @return [String]
  # @!attribute [r] endpoint_name
  #   @return [String]
  # @!attribute [r] message
  #   @return [String]
  # @!attribute [r] sent_at
  #   @return [Time, nil]
  Ping = Data.define(:endpoint_id, :endpoint_name, :message, :sent_at) do
    include Model::Raw

    # @api private
    def self.from_api(hash)
      Model.build(self, hash, sent_at: Model.time(hash["sent_at"]))
    end
  end
end
