# frozen_string_literal: true

require_relative "test_helper"

class EventsTest < Minitest::Test
  W = WebsiteScreenshotWorld

  EXPECTED = {
    "auto-schedule.capture.changed.json" => [W::CaptureChangedEvent, W::ScheduledCapture],
    "auto-schedule.capture.failed.json" => [W::CaptureFailedEvent, W::ScheduledCapture],
    "auto-schedule.capture.succeeded.json" => [W::CaptureSucceededEvent, W::ScheduledCapture],
    "auto-schedule.delivery.completed.json" => [W::DeliveryCompletedEvent, W::ScheduledCapture],
    "auto-schedule.ping.json" => [W::PingEvent, W::Ping],
    "auto-schedule.schedule.paused.json" => [W::SchedulePausedEvent, W::SchedulePause],
    "auto-schedule.sitemap_run.completed.json" => [W::SitemapRunCompletedEvent, W::SitemapRun],
    "instant-snap.capture.failed.json" => [W::CaptureFailedEvent, W::Capture],
    "instant-snap.capture.succeeded.json" => [W::CaptureSucceededEvent, W::Capture],
    "unknown.json" => [W::UnknownEvent, Hash]
  }.freeze

  def test_every_example_is_covered
    assert_equal EXPECTED.keys.sort, Dir[File.join(SPEC_DIR, "events", "*.json")].map { File.basename(_1) }.sort
  end

  EXPECTED.each do |file, (event_class, data_class)|
    define_method("test_#{file.delete_suffix(".json").tr(".-", "__")}") do
      hash = spec_json("events", file)
      event = event(hash)

      assert_instance_of event_class, event
      assert_kind_of W::Event, event
      assert_kind_of data_class, event.data
      assert_equal hash.fetch("type"), event.type
      assert_equal hash.fetch("product"), event.product
      assert_equal Time.utc(2026, 9, 26, 10, 30, 5), event.created_at
    end
  end

  def test_unknown_event_keeps_type_and_raw_data
    event = event_from("unknown.json")

    assert_equal "capture.teleported", event.type
    assert_equal({ "anything" => 1 }, event.data)
  end

  def test_instant_snap_capture_data
    data = event_from("instant-snap.capture.failed.json").data

    assert_equal "capture_failed", data.error_code
    assert_nil data.download_url
    assert_equal Time.utc(2026, 9, 26, 10, 30, 4.512r), data.captured_at
  end

  def test_delivery_destinations
    destination = event_from("auto-schedule.delivery.completed.json").data.destinations.first

    assert_equal ["Marketing bucket", "aws_s3", Time.utc(2026, 9, 26, 10, 30, 9)],
                 [destination.name, destination.provider, destination.completed_at]
  end

  def test_capture_changed_fields
    data = event_from("auto-schedule.capture.changed.json").data

    assert_in_delta 12.5, data.change_percent
    assert data.change_image_available
    assert_equal "abababababababababababababababababababababababababababababababab", data.page_source.sha256
  end

  def test_sitemap_run_counts
    run = event_from("auto-schedule.sitemap_run.completed.json").data

    assert_equal [120, 80, 50, 48, 2, 30, 0],
                 [run.pages_listed, run.pages_matched, run.pages_queued, run.pages_succeeded, run.pages_failed,
                  run.pages_over_limit, run.pages_over_quota]
    assert_equal Time.utc(2026, 9, 26, 10), run.run_at
  end

  def test_pattern_matching
    matched =
      case event_from("auto-schedule.schedule.paused.json")
      in { type: "schedule.paused", data: { reason: } } then reason
      end

    assert_equal "quota_exhausted", matched
  end

  private

  def event_from(file)
    event(spec_json("events", file))
  end

  # Signs and verifies the example, as a real delivery would be.
  def event(hash)
    body = JSON.generate(hash)
    timestamp = 1_790_418_600
    signature = OpenSSL::HMAC.hexdigest("SHA256", "secret", "#{timestamp}.#{body}")
    W::Webhook.verify(body, "t=#{timestamp},v1=#{signature}", "secret", now: Time.at(timestamp))
  end
end
