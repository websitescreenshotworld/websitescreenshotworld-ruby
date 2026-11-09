# frozen_string_literal: true

require_relative "test_helper"
require "socket"

class RetryTest < Minitest::Test
  include ServerHelpers

  W = WebsiteScreenshotWorld

  def test_retry_after_header_stands_in_for_a_missing_body
    busy = { status: 503, headers: { "Retry-After" => "0" }, body_text: "busy" }
    ConformanceServer.load([busy] * 3)
    error = assert_raises(W::ServiceError) { conformance_client.instant_snap.catalog }

    assert_equal ["service_unavailable", 0, "busy"], [error.error_code, error.retry_after_seconds, error.body]
    assert_equal 3, ConformanceServer.requests.size
  end

  def test_a_wait_past_the_deadline_stops_retrying_at_once
    ConformanceServer.load([
                             json_response(refusal("rate_limited", 30), status: 429),
                             json_response(capture_body)
                           ])
    started = clock
    error = assert_raises(W::RateLimitError) do
      conformance_client.instant_snap.capture(url: "https://example.com", timeout: 5)
    end

    assert_equal 30, error.retry_after_seconds
    assert_equal 1, ConformanceServer.requests.size
    assert_operator clock - started, :<, 1
  end

  def test_a_redirect_is_not_followed
    moved = { status: 302, headers: { "Location" => "#{ConformanceServer.url}/elsewhere" }, body_text: "" }
    ConformanceServer.load([moved, json_response({ "success" => true })])
    error = assert_raises(W::Error) { conformance_client.instant_snap.catalog }

    assert_equal 302, error.http_status
    assert_equal 1, ConformanceServer.requests.size
  end

  def test_queue_full_is_not_retried
    ConformanceServer.load([
                             json_response(refusal("queue_full", 0), status: 429),
                             json_response(capture_body("status" => "queued"), status: 202)
                           ])
    error = assert_raises(W::RateLimitError) { conformance_client.instant_snap.submit(url: "https://example.com") }

    assert_equal ["queue_full", 0], [error.error_code, error.retry_after_seconds]
    assert_equal 1, ConformanceServer.requests.size
  end

  def test_max_retries_zero_turns_retrying_off
    ConformanceServer.load([json_response(refusal("capture_busy", 0), status: 503)])

    assert_raises(W::ServiceError) do
      conformance_client(max_retries: 0).instant_snap.capture(url: "https://example.com")
    end
    assert_equal 1, ConformanceServer.requests.size
  end

  def test_connection_failure_raises_connection_error
    client = W::Client.new(instant_snap_api_key: "k", instant_snap_base_url: "http://127.0.0.1:#{closed_port}",
                           max_retries: 1)
    error = assert_raises(W::ConnectionError) { client.instant_snap.catalog }

    assert_kind_of SystemCallError, error.cause
    assert_nil error.http_status
  end

  def test_timeout_raises_connection_error
    server = TCPServer.new("127.0.0.1", 0)
    client = W::Client.new(instant_snap_api_key: "k", instant_snap_base_url: "http://127.0.0.1:#{server.addr[1]}")
    started = clock

    assert_raises(W::ConnectionError) { client.instant_snap.capture(url: "https://example.com", timeout: 0.3) }
    assert_operator clock - started, :<, 1.5
  ensure
    server&.close
  end

  def test_submit_uses_the_ordinary_timeout
    server = TCPServer.new("127.0.0.1", 0)
    client = W::Client.new(instant_snap_api_key: "k", instant_snap_base_url: "http://127.0.0.1:#{server.addr[1]}",
                           timeout: 0.3)
    started = clock

    assert_raises(W::ConnectionError) { client.instant_snap.submit(url: "https://example.com") }
    assert_operator clock - started, :<, 1.5
  ensure
    server&.close
  end

  private

  def refusal(code, retry_after)
    { "success" => false, "error_code" => code, "error_message" => "Try later.", "retry_after_seconds" => retry_after }
  end

  def closed_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1].tap { server.close }
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
