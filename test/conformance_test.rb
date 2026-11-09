# frozen_string_literal: true

require_relative "test_helper"

# Runs every case in spec/fixtures against conformance/server.js, as spec/README.md "Fixtures" describes.
class ConformanceTest < Minitest::Test
  include ServerHelpers

  ERROR_CLASSES = {
    "base" => WebsiteScreenshotWorld::Error,
    "authentication" => WebsiteScreenshotWorld::AuthenticationError,
    "invalid_request" => WebsiteScreenshotWorld::InvalidRequestError,
    "plan_limit" => WebsiteScreenshotWorld::PlanLimitError,
    "not_found" => WebsiteScreenshotWorld::NotFoundError,
    "rate_limit" => WebsiteScreenshotWorld::RateLimitError,
    "capture" => WebsiteScreenshotWorld::CaptureError,
    "service" => WebsiteScreenshotWorld::ServiceError
  }.freeze

  # Each fixture's call, made with the arguments spec/README.md "Fixtures" names.
  CALLS = {
    %w[instant_snap capture] => ->(client, _, options) { client.instant_snap.capture(**options) },
    %w[instant_snap capture_to_bucket] => ->(client, _, options) { client.instant_snap.capture_to_bucket(**options) },
    %w[instant_snap capture_file] => lambda do |client, _, options|
      client.instant_snap.capture_file(**options) { |file| file_fields(file) }
    end,
    %w[instant_snap submit] => ->(client, _, options) { client.instant_snap.submit(**options) },
    %w[instant_snap submit_to_bucket] => ->(client, _, options) { client.instant_snap.submit_to_bucket(**options) },
    %w[instant_snap wait] => lambda do |client, call, _|
      settings = call.slice("timeout_seconds", "poll_interval_seconds").transform_keys(&:to_sym)
      client.instant_snap.wait(call.fetch("id"), **settings)
    end,
    %w[instant_snap get] => ->(client, call, _) { client.instant_snap.get(call.fetch("id")) },
    %w[instant_snap defaults] => ->(client, _, _) { client.instant_snap.defaults },
    %w[instant_snap catalog] => ->(client, _, _) { client.instant_snap.catalog },
    %w[auto_schedule trigger_now] => lambda do |client, call, _|
      client.auto_schedule.trigger_now(call.fetch("web_page_id"))
    end
  }.freeze

  FIXTURES = Dir[File.join(SPEC_DIR, "fixtures", "*.json")].reject { File.basename(_1) == "keys.json" }.sort

  FIXTURES.each do |path|
    fixture = JSON.parse(File.read(path, encoding: Encoding::UTF_8))
    define_method("test_#{fixture.fetch("name")}") { run_fixture(fixture) }
  end

  # For capture_file the result is the file's fields plus +body_sha256+, the digest of the bytes read.
  def self.file_fields(file)
    fields = %w[id status content_type width height page_http_status final_url sha256 filename]
    fields.to_h { [_1, file.public_send(_1)] }.merge("body_sha256" => Digest::SHA256.hexdigest(file.read))
  end

  def test_every_fixture_is_run
    assert_operator FIXTURES.size, :>=, 26
  end

  private

  def run_fixture(fixture)
    ConformanceServer.load(fixture.fetch("responses"))
    outcome = begin
      invoke(fixture.fetch("call"))
    rescue WebsiteScreenshotWorld::Error => e
      e
    end

    assert_requests(fixture.fetch("expect_requests"), ConformanceServer.requests)
    expect = fixture.fetch("expect")
    if expect.key?("error")
      assert_error(expect.fetch("error"), outcome)
    else
      refute_kind_of Exception, outcome
      assert_fields(expect.fetch("result"), outcome)
    end
  end

  def invoke(call)
    options = call.fetch("options", {}).transform_keys(&:to_sym)
    options[:idempotency_key] = call["idempotency_key"] if call.key?("idempotency_key")
    CALLS.fetch([call.fetch("product"), call.fetch("method")]).call(conformance_client, call, options)
  end

  def assert_requests(expected, received)
    assert_equal expected.size, received.size, "number of requests"
    expected.zip(received).each { |want, got| assert_request(want, got) }
    assert_idempotency_keys(expected, received)
  end

  def assert_request(want, got)
    assert_equal want.fetch("method"), got.fetch("method")
    assert_equal want.fetch("path"), got.fetch("path")
    want.fetch("headers").each do |name, value|
      assert_equal value, got.fetch("headers")[name.downcase], "header #{name}"
    end
    return unless want.key?("body")

    body = got.fetch("body")&.then { JSON.parse(_1) }
    want.fetch("body").nil? ? assert_nil(body) : assert_equal(want.fetch("body"), body)
  end

  def assert_idempotency_keys(expected, received)
    keys = received.map { _1.fetch("headers")["idempotency-key"] }
    modes = expected.filter_map { _1["idempotency_key"] }
    return if modes.empty?

    keys.each { refute_empty(_1.to_s, "Idempotency-Key") }
    assert_equal 1, keys.uniq.size, "one Idempotency-Key for the whole call" if modes.include?("same")
  end

  def assert_error(expected, error)
    assert_instance_of ERROR_CLASSES.fetch(expected.fetch("kind")), error
    assert_equal expected.fetch("error_code"), error.error_code
    assert_equal expected.fetch("http_status"), error.http_status
    assert_equal expected.fetch("message"), error.message if expected.key?("message")
    return unless expected.key?("retry_after_seconds")

    assert_equal expected.fetch("retry_after_seconds"), error.retry_after_seconds
  end

  def assert_fields(expected, actual, path = "result")
    expected.each do |name, value|
      field = actual.is_a?(Hash) ? actual.fetch(name) : actual.public_send(name)
      if value.is_a?(Hash)
        refute_nil field, "#{path}.#{name}"
        assert_fields(value, field, "#{path}.#{name}")
      elsif value.nil?
        assert_nil field, "#{path}.#{name}"
      else
        assert_equal value, field, "#{path}.#{name}"
      end
    end
  end
end
