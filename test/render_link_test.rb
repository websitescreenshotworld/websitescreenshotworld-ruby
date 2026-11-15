# frozen_string_literal: true

require_relative "test_helper"

class RenderLinkTest < Minitest::Test
  VECTORS = spec_json("render-link-vectors.json")
  RenderLink = WebsiteScreenshotWorld::RenderLink

  VECTORS.fetch("cases").each do |vector|
    define_method("test_vector_#{vector.fetch("name")}") do
      arguments = {
        render_secret: vector.fetch("render_secret"),
        key_prefix: vector.fetch("key_prefix")
      }
      arguments[:format] = vector.fetch("format") if vector.key?("format")
      arguments[:base_url] = vector.fetch("base_url") if vector.key?("base_url")
      vector.fetch("options").each { |name, value| arguments[name.to_sym] = value }

      assert_equal vector.fetch("url"), RenderLink.build(**arguments)
    end
  end

  VALID = { render_secret: "wsw_rsk_x", key_prefix: "0123456789ab", url: "https://example.com" }.freeze

  [
    { render_secret: "" }, { key_prefix: "0123456789AB" }, { key_prefix: "wsw_api_0123" }, { url: "" },
    { format: "image_pdf" }, { headers: "X: 1" }
  ].each_with_index do |change, index|
    define_method("test_refuses_what_cannot_be_a_link_#{index}") do
      assert_raises(ArgumentError) { RenderLink.build(**VALID, **change) }
    end
  end

  def test_leaves_out_an_option_that_is_not_set
    link = RenderLink.build(**VALID, width: nil, block_ads: false)

    assert_includes link, "block_ads=false"
    refute_includes link, "width="
    assert_match(/&sig=[0-9a-f]{64}\z/, link)
  end
end
