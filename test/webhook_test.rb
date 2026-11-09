# frozen_string_literal: true

require_relative "test_helper"

class WebhookTest < Minitest::Test
  VECTORS = spec_json("webhook-vectors.json")
  Webhook = WebsiteScreenshotWorld::Webhook

  VECTORS.fetch("cases").each do |vector|
    define_method("test_vector_#{vector.fetch("name")}") do
      verify = lambda do
        Webhook.verify(vector.fetch("body"), vector.fetch("header"), VECTORS.fetch("secret"),
                       tolerance: vector.fetch("tolerance", Webhook::DEFAULT_TOLERANCE),
                       now: Time.at(vector.fetch("now")))
      end

      if vector.fetch("valid")
        event = verify.call

        assert_instance_of WebsiteScreenshotWorld::PingEvent, event
        assert_equal "ping", event.type
      else
        assert_raises(WebsiteScreenshotWorld::SignatureVerificationError) { verify.call }
      end
    end
  end

  def test_signature_error_is_a_library_error
    assert_operator WebsiteScreenshotWorld::SignatureVerificationError, :<, WebsiteScreenshotWorld::Error
  end

  def test_body_verifies_whatever_its_encoding_tag
    vector = VECTORS.fetch("cases").find { _1.fetch("name") == "non_ascii_body" }
    [Encoding::BINARY, Encoding::US_ASCII].each do |encoding|
      body = vector.fetch("body").dup.force_encoding(encoding)
      event = Webhook.verify(body, vector.fetch("header"), VECTORS.fetch("secret"), now: Time.at(vector.fetch("now")))

      assert_equal "Prod\u00fcction", event.data.endpoint_name
    end
  end

  def test_missing_header_is_a_signature_error
    assert_raises(WebsiteScreenshotWorld::SignatureVerificationError) do
      Webhook.verify("{}", nil, VECTORS.fetch("secret"))
    end
  end

  def test_parsed_payload_is_refused
    error = assert_raises(ArgumentError) { Webhook.verify({ "type" => "ping" }, "t=1,v1=00", "secret") }

    assert_match(/raw request body/, error.message)
  end

  def test_empty_secret_is_refused
    assert_raises(ArgumentError) { Webhook.verify("{}", "t=1,v1=00", "") }
  end

  def test_now_defaults_to_the_current_time
    body = '{"id":"1","type":"ping","created_at":"2026-09-26T10:30:00.000Z","product":"auto_schedule","data":{}}'
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", "secret", "#{timestamp}.#{body}")

    assert_instance_of WebsiteScreenshotWorld::PingEvent,
                       Webhook.verify(body, "t=#{timestamp},v1=#{signature}", "secret")
  end
end
