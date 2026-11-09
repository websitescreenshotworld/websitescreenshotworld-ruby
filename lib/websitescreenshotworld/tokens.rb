# frozen_string_literal: true

module WebsiteScreenshotWorld
  # Values of +status+ on a {Capture}. Compare with these rather than literals; a value added later still
  # comes through as a plain String.
  module CaptureStatus
    # An async capture was accepted and is waiting for a browser.
    QUEUED = "queued"
    # A browser is taking an async capture.
    RUNNING = "running"
    PENDING = "pending"
    SUCCEEDED = "succeeded"
    # The end state of a +by_format+ capture: the file went back in the response and is not kept.
    DELIVERED = "delivered"
    FAILED = "failed"
    TIMED_OUT = "timed_out"
    EXPIRED = "expired"
  end

  # Values of +response_type+. The capture methods set it themselves.
  module ResponseType
    JSON = "json"
    BY_FORMAT = "by_format"
    CLOUD_STORAGE = "cloud_storage"
  end

  # Values of the +media_category+ option and field.
  module MediaCategory
    IMAGE = "image"
    VIDEO = "video"
    PDF = "pdf"
  end

  # Values of the +format+ option and field. Each belongs to one {MediaCategory}.
  module Format
    PNG = "png"
    JPEG = "jpeg"
    WEBP = "webp"
    TIFF = "tiff"
    MP4 = "mp4"
    WEBM = "webm"
    MOV = "mov"
    GIF = "gif"
    IMAGE_PDF = "image_pdf"
    DOCUMENT_PDF = "document_pdf"
  end

  # Values of the +device_category+ option.
  module DeviceCategory
    DESKTOP = "desktop"
    MOBILE = "mobile"
  end

  # Values of the +scroll_mode+ option. +SCROLL+ captures the full page.
  module ScrollMode
    VIEWPORT = "viewport"
    SCROLL = "scroll"
  end

  # Values of +timestamp_watermark: { location: }+.
  module WatermarkLocation
    TOP = "top"
    BOTTOM = "bottom"
  end

  # Values of +page_source: { format: }+ and {PageSource#format}.
  module PageSourceFormat
    HTML = "html"
    JSON = "json"
    TEXT = "text"
  end

  # Values of {S3Delivery#status}.
  module S3DeliveryStatus
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
  end

  # Values of {TriggerResult#status}.
  module TriggerStatus
    TRIGGERED = "triggered"
    # A capture for this web page was already queued or running: nothing new started, nothing was charged.
    ALREADY_PENDING = "already_pending"
  end

  # Values of {TriggerResult#triggered_by}.
  module TriggeredBy
    API = "api"
    UI = "ui"
  end

  # Values of {Event#product}.
  module Product
    INSTANT_SNAP = "instant_snap"
    AUTO_SCHEDULE = "auto_schedule"
  end

  # Values of {Event#type}.
  module EventType
    CAPTURE_SUCCEEDED = "capture.succeeded"
    CAPTURE_FAILED = "capture.failed"
    DELIVERY_COMPLETED = "delivery.completed"
    CAPTURE_CHANGED = "capture.changed"
    SCHEDULE_PAUSED = "schedule.paused"
    SITEMAP_RUN_COMPLETED = "sitemap_run.completed"
    PING = "ping"
  end
end
