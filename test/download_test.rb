# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tmpdir"

class DownloadTest < Minitest::Test
  include ServerHelpers

  W = WebsiteScreenshotWorld

  def test_writes_the_file_to_a_path_without_the_api_key
    ConformanceServer.load([file_response("png-bytes")])
    Dir.mktmpdir do |dir|
      path = File.join(dir, "page.png")
      returned = client.download(capture, path)

      assert_equal path, returned
      assert_equal "png-bytes", File.binread(path)
    end

    request = ConformanceServer.requests.first
    assert_equal "/s/0.png?e=1&s=abc", request.fetch("path")
    refute request.fetch("headers").key?("x-api-key")
    refute_equal "application/json", request.dig("headers", "accept")
  end

  def test_writes_to_an_io
    ConformanceServer.load([file_response("<html></html>")])
    io = StringIO.new(+"")
    source = W::PageSource.from_api({ "format" => "html", "download_url" => "#{ConformanceServer.url}/s/x.html" })
    client.download(source, io)

    assert_equal "<html></html>", io.string
  end

  def test_refusal_leaves_no_file
    ConformanceServer.load([{ status: 404, headers: { "Content-Type" => "text/plain" }, body_text: "gone" }])
    Dir.mktmpdir do |dir|
      path = File.join(dir, "page.png")

      assert_raises(W::NotFoundError) { client.download(capture, path) }
      refute_path_exists path
    end
  end

  def test_capture_without_a_download_url
    assert_raises(ArgumentError) { client.download(W::Capture.from_api({ "download_url" => nil }), StringIO.new) }
  end

  private

  def client
    conformance_client.instant_snap
  end

  def capture
    W::Capture.from_api({ "download_url" => "#{ConformanceServer.url}/s/0.png?e=1&s=abc" })
  end

  def file_response(text)
    { status: 200, headers: { "Content-Type" => "application/octet-stream" }, body_text: text }
  end
end
