# frozen_string_literal: true

module WebsiteScreenshotWorld
  # A webhook delivery, as returned by {Webhook.verify}. Each type has its own subclass, so a +case+ on the
  # class (or pattern matching on +type+ and +data+) picks the handler.
  #
  # @!attribute [r] id
  #   @return [String] the delivery id
  # @!attribute [r] type
  #   @return [String] one of {EventType}, or a type added later
  # @!attribute [r] created_at
  #   @return [Time, nil]
  # @!attribute [r] product
  #   @return [String] one of {Product}
  # @!attribute [r] data
  #   @return [Object] the typed payload; see each subclass
  Event = Data.define(:id, :type, :created_at, :product, :data) do
    include Model::Raw
  end

  # +capture.succeeded+. {#data} is a {Capture} for Instant Snap and a {ScheduledCapture} for Auto Schedule.
  class CaptureSucceededEvent < Event; end

  # +capture.failed+. {#data} is a {Capture} for Instant Snap and a {ScheduledCapture} for Auto Schedule.
  class CaptureFailedEvent < Event; end

  # +delivery.completed+ (Auto Schedule). {#data} is a {ScheduledCapture} with its +destinations+.
  class DeliveryCompletedEvent < Event; end

  # +capture.changed+ (Auto Schedule). {#data} is a {ScheduledCapture} with its +change_percent+.
  class CaptureChangedEvent < Event; end

  # +schedule.paused+ (Auto Schedule). {#data} is a {SchedulePause}.
  class SchedulePausedEvent < Event; end

  # +sitemap_run.completed+ (Auto Schedule). {#data} is a {SitemapRun}.
  class SitemapRunCompletedEvent < Event; end

  # +ping+, a test delivery. {#data} is a {Ping}.
  class PingEvent < Event; end

  # A type this version of the library does not know yet. {#type} names it and {#data} is the raw Hash.
  class UnknownEvent < Event; end

  # The subclasses exist only now, so the table that picks one is added here.
  class Event
    TYPES = {
      EventType::DELIVERY_COMPLETED => [DeliveryCompletedEvent, ScheduledCapture],
      EventType::CAPTURE_CHANGED => [CaptureChangedEvent, ScheduledCapture],
      EventType::SCHEDULE_PAUSED => [SchedulePausedEvent, SchedulePause],
      EventType::SITEMAP_RUN_COMPLETED => [SitemapRunCompletedEvent, SitemapRun],
      EventType::PING => [PingEvent, Ping]
    }.freeze
    private_constant :TYPES

    # @api private
    def self.from_api(hash)
      klass, data_class = classes_for(hash["type"], hash["product"])
      data = hash["data"]
      data = data_class.from_api(data) if data_class && data.is_a?(Hash)
      Model.build(klass, hash, created_at: Model.time(hash["created_at"]), data: data)
    end

    def self.classes_for(type, product)
      capture_class = product == Product::INSTANT_SNAP ? Capture : ScheduledCapture
      case type
      when EventType::CAPTURE_SUCCEEDED then [CaptureSucceededEvent, capture_class]
      when EventType::CAPTURE_FAILED then [CaptureFailedEvent, capture_class]
      else TYPES.fetch(type, [UnknownEvent, nil])
      end
    end
    private_class_method :classes_for
  end
end
