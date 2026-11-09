# frozen_string_literal: true

require_relative "test_helper"

class ModelTest < Minitest::Test
  Model = WebsiteScreenshotWorld::Model

  def test_dates_parse_leniently_to_utc
    expected = Time.utc(2026, 9, 26, 10, 30, 4.512r)

    assert_equal expected, Model.time("2026-09-26T10:30:04.512Z")
    assert_equal expected, Model.time("2026-09-26T10:30:04.512000Z")
    assert_equal expected, Model.time("2026-09-26T16:00:04.512+05:30")
    assert_equal Time.utc(2026, 9, 26, 10, 30, 4), Model.time("2026-09-26T10:30:04Z")
    assert_predicate Model.time("2026-09-26T16:00:04.512+05:30"), :utc?
  end

  def test_missing_or_malformed_dates_are_nil
    assert_nil Model.time(nil)
    assert_nil Model.time("yesterday")
  end

  def test_capture_fields
    capture = WebsiteScreenshotWorld::Capture.from_api(
      { "id" => "c1", "expires_at" => "2026-09-27T10:30:04.512Z",
        "s3_delivery" => { "status" => "completed", "bucket" => "b", "key" => "site/c1.png" } }
    )

    assert_equal Time.utc(2026, 9, 27, 10, 30, 4.512r), capture.expires_at
    assert_equal WebsiteScreenshotWorld::S3DeliveryStatus::COMPLETED, capture.s3_delivery.status
    assert_nil capture.page_source
    refute_predicate capture, :idempotent_replayed?
  end

  def test_defaults_viewport
    defaults = WebsiteScreenshotWorld::Defaults.from_api(
      { "viewport" => { "width" => 1920, "height" => 1080, "device_scale_factor" => 1 }, "zoom" => 100 }
    )

    assert_equal 1920, defaults.viewport.width
    assert_equal 100, defaults.zoom
    assert_nil defaults.limits
  end
end
