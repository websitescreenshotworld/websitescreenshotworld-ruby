# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tmpdir"

class CaptureFileTest < Minitest::Test
  include ServerHelpers

  BYTES = Random.new(7).bytes(200_003).freeze
  HEADERS = {
    "Content-Type" => "image/png",
    "Content-Disposition" => "attachment; filename=\"page.png\"",
    "X-InstantSnap-Id" => "3f6c2a1e-9b8d-4c7e-a5f4-1d2e3c4b5a69",
    "X-InstantSnap-Status" => "delivered",
    "X-InstantSnap-Size-Bytes" => BYTES.bytesize.to_s,
    "X-InstantSnap-Duration-Ms" => "3900",
    "X-InstantSnap-Spec-Version" => "v1",
    "X-InstantSnap-Captured-At" => "2026-09-26T10:30:04.512Z",
    "X-InstantSnap-Part-Count" => "2"
  }.freeze

  def setup
    ConformanceServer.load([file_response])
  end

  def test_block_form_streams_and_returns_the_block_value
    result = client.capture_file(url: "https://example.com") do |file|
      assert_nil file.path
      Digest::SHA256.hexdigest(file.read)
    end

    assert_equal Digest::SHA256.hexdigest(BYTES), result
    assert_equal "*/*", ConformanceServer.requests.first.dig("headers", "accept")
  end

  def test_metadata
    client.capture_file(url: "https://example.com") do |file|
      assert_equal "page.png", file.filename
      assert_equal BYTES.bytesize, file.size_bytes
      assert_equal 3900, file.duration_ms
      assert_equal 2, file.part_count
      assert_equal "v1", file.spec_version
      assert_equal Time.utc(2026, 9, 26, 10, 30, 4.512r), file.captured_at
      assert_nil file.width
    end
  end

  def test_block_form_saves_to_a_path
    Dir.mktmpdir do |dir|
      path = File.join(dir, "page.png")
      client.capture_file(url: "https://example.com") { _1.save(path) }

      assert_equal BYTES, File.binread(path)
    end
  end

  def test_block_can_leave_the_body_unread
    assert_equal "page.png", client.capture_file(url: "https://example.com", &:filename)
  end

  def test_without_a_block_the_file_is_buffered
    file = client.capture_file(url: "https://example.com")

    assert File.exist?(file.path)
    io = StringIO.new(+"", "wb")
    file.save(io)

    assert_equal BYTES, io.string
  ensure
    file&.close
  end

  def test_body_is_read_once
    file = client.capture_file(url: "https://example.com")
    file.read

    assert_raises(IOError) { file.read }
  ensure
    file&.close
  end

  def test_each_chunk_without_a_block
    client.capture_file(url: "https://example.com") do |file|
      assert_equal BYTES, file.each_chunk.to_a.join
    end
  end

  def test_error_in_the_block_passes_through
    assert_raises(Errno::ENOENT) do
      client.capture_file(url: "https://example.com") { _1.save("/nonexistent/dir/page.png") }
    end
  end

  def test_filename_forms
    parse = WebsiteScreenshotWorld::CaptureFile.method(:filename_from)

    assert_equal "a b.png", parse.call("attachment; filename=\"a b.png\"")
    assert_equal "plain.png", parse.call("attachment; filename=plain.png")
    assert_equal "café.png", parse.call("attachment; filename=\"cafe.png\"; filename*=UTF-8''caf%C3%A9.png")
    assert_equal "passwd", parse.call("attachment; filename=\"../../etc/passwd\"")
    assert_nil parse.call("inline")
    assert_nil parse.call(nil)
  end

  private

  def client
    conformance_client.instant_snap
  end

  def file_response
    { status: 200, headers: HEADERS, body_base64: [BYTES].pack("m0") }
  end
end
