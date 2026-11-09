# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  include ServerHelpers

  W = WebsiteScreenshotWorld
  TRIGGER = {
    "success" => true, "status" => "triggered", "web_page_id" => "7d4e2b1a-6c5f-4a3e-9d8c-2b1a0f9e8d7c",
    "triggered_by" => "api", "triggered_at" => "2026-09-26T10:30:00.000Z", "message" => "Queued."
  }.freeze

  def test_missing_instant_snap_key_fails_before_sending
    ConformanceServer.load([])
    client = W::Client.new(instant_snap_api_key: nil, instant_snap_base_url: ConformanceServer.url)

    error = assert_raises(W::AuthenticationError) { client.instant_snap.capture(url: "https://example.com") }
    assert_match(/WSW_INSTANT_SNAP_API_KEY/, error.message)
    assert_raises(W::AuthenticationError) { client.instant_snap.capture_file(url: "https://example.com") }
    assert_empty ConformanceServer.requests
  end

  def test_missing_auto_schedule_key_fails_before_sending
    ConformanceServer.load([])
    client = W::Client.new(auto_schedule_api_key: "", auto_schedule_base_url: ConformanceServer.url)

    error = assert_raises(W::AuthenticationError) { client.auto_schedule.trigger_now("x") }
    assert_match(/WSW_AUTO_SCHEDULE_API_KEY/, error.message)
    assert_empty ConformanceServer.requests
  end

  def test_keys_default_from_the_environment
    ENV["WSW_AUTO_SCHEDULE_API_KEY"] = "from-env"
    ConformanceServer.load([json_response(TRIGGER)])
    W::Client.new(auto_schedule_base_url: ConformanceServer.url).auto_schedule.trigger_now("x")

    assert_equal "from-env", ConformanceServer.requests.first.dig("headers", "x-api-key")
  ensure
    ENV.delete("WSW_AUTO_SCHEDULE_API_KEY")
  end

  def test_defaults_need_no_key
    ConformanceServer.load([json_response({ "success" => true, "spec_version" => "v1" })])
    defaults = W::Client.new(instant_snap_api_key: nil, instant_snap_base_url: ConformanceServer.url)
                        .instant_snap.defaults

    assert_equal "v1", defaults.spec_version
    refute ConformanceServer.requests.first.fetch("headers").key?("x-api-key")
  end

  def test_json_request_headers
    ConformanceServer.load([json_response(capture_body)])
    conformance_client.instant_snap.capture(url: "https://example.com")
    headers = ConformanceServer.requests.first.fetch("headers")

    assert_equal "application/json", headers.fetch("accept")
    assert_equal "application/json", headers.fetch("content-type")
    assert_match(%r{\Awebsitescreenshotworld-ruby/0\.1\.0 \(ruby \d+\.\d+\.\d+\)\z}, headers.fetch("user-agent"))
    assert_match(/\A\h{8}-\h{4}-4\h{3}-[89ab]\h{3}-\h{12}\z/, headers.fetch("idempotency-key"))
  end

  def test_each_call_gets_its_own_idempotency_key
    ConformanceServer.load([json_response(capture_body), json_response(capture_body)])
    2.times { conformance_client.instant_snap.capture(url: "https://example.com") }
    keys = ConformanceServer.requests.map { _1.dig("headers", "idempotency-key") }

    refute_equal keys.first, keys.last
  end

  def test_trigger_now_sends_no_body_and_no_content_type
    ConformanceServer.load([json_response(TRIGGER)])
    result = conformance_client.auto_schedule.trigger_now("7d4e2b1a-6c5f-4a3e-9d8c-2b1a0f9e8d7c")
    request = ConformanceServer.requests.first

    assert_nil request.fetch("body")
    refute request.fetch("headers").key?("content-type")
    assert_equal Time.utc(2026, 9, 26, 10, 30), result.triggered_at
  end

  def test_get_escapes_the_id
    ConformanceServer.load([json_response(capture_body)])
    conformance_client.instant_snap.get("a b/c")

    assert_equal "/instant-snap/v1/captures/a%20b%2Fc", ConformanceServer.requests.first.fetch("path")
  end

  def test_unknown_option_is_refused_before_sending
    ConformanceServer.load([])
    error = assert_raises(ArgumentError) do
      conformance_client.instant_snap.capture(url: "https://example.com", viewprot: { width: 800 })
    end

    assert_equal "unknown keyword: :viewprot", error.message
    assert_empty ConformanceServer.requests
  end

  def test_response_type_is_not_an_option
    assert_raises(ArgumentError) do
      conformance_client.instant_snap.capture(url: "https://example.com", response_type: "by_format")
    end
  end

  def test_nil_options_are_not_sent_and_false_is
    ConformanceServer.load([json_response(capture_body)])
    conformance_client.instant_snap.capture(url: "https://example.com", format: nil, block_ads: false, zoom: 0,
                                            user_agent: "", viewport: { width: 1440, height: nil })

    assert_equal({ "url" => "https://example.com", "block_ads" => false, "zoom" => 0, "user_agent" => "",
                   "viewport" => { "width" => 1440 }, "response_type" => "json" },
                 JSON.parse(ConformanceServer.requests.first.fetch("body")))
  end

  def test_async_is_set_by_submit_not_by_the_caller
    assert_raises(ArgumentError) do
      conformance_client.instant_snap.submit(url: "https://example.com", async: false)
    end
    ConformanceServer.load([json_response(capture_body("status" => "queued"), status: 202)])
    capture = conformance_client.instant_snap.submit(url: "https://example.com")

    assert_equal W::CaptureStatus::QUEUED, capture.status
    assert_equal({ "url" => "https://example.com", "response_type" => "json", "async" => true },
                 JSON.parse(ConformanceServer.requests.first.fetch("body")))
  end

  def test_wait_returns_the_last_capture_read_when_time_runs_out
    ConformanceServer.load([json_response(capture_body("status" => "running"))] * 3)
    capture = conformance_client.instant_snap.wait("3f6c2a1e", timeout_seconds: 0)

    assert_equal W::CaptureStatus::RUNNING, capture.status
    assert_equal 1, ConformanceServer.requests.size
  end

  def test_wait_takes_a_capture_and_raises_what_get_raises
    refusal = { "success" => false, "error_code" => "capture_not_found", "error_message" => "No such capture." }
    ConformanceServer.load([json_response(refusal, status: 404)])
    queued = W::Capture.from_api(capture_body("id" => "3f6c2a1e", "status" => "queued"))

    error = assert_raises(W::NotFoundError) { conformance_client.instant_snap.wait(queued, poll_interval_seconds: 0) }
    assert_equal "capture_not_found", error.error_code
    assert_equal "/instant-snap/v1/captures/3f6c2a1e", ConformanceServer.requests.first.fetch("path")
  end

  def test_idempotent_replayed
    ConformanceServer.load([json_response(capture_body, headers: { "Idempotent-Replayed" => "true" })])
    capture = conformance_client.instant_snap.capture(url: "https://example.com", idempotency_key: "k-1")

    assert_predicate capture, :idempotent_replayed?
  end

  def test_results_drop_success_and_keep_unknown_fields
    ConformanceServer.load([json_response(capture_body("added_later" => 1))])
    capture = conformance_client.instant_snap.capture(url: "https://example.com")

    refute capture.raw.key?("success")
    assert_equal 1, capture.raw.fetch("added_later")
    assert_predicate capture, :frozen?
    assert_predicate capture.raw, :frozen?
  end

  def test_success_body_that_is_not_json
    ConformanceServer.load([{ status: 200, headers: { "Content-Type" => "text/html" }, body_text: "<html>" }])
    error = assert_raises(W::Error) { conformance_client.instant_snap.catalog }

    assert_equal 200, error.http_status
    assert_equal "<html>", error.body
  end

  def test_inspect_hides_the_keys
    refute_includes conformance_client.inspect, KEYS.fetch("instant_snap")
  end
end
