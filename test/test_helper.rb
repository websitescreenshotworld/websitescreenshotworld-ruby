# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "websitescreenshotworld"
require "digest"
require "minitest/autorun"

SPEC_DIR = File.expand_path("../spec", __dir__)

# Reads a JSON file under spec/ as UTF-8, whatever the locale.
def spec_json(*path)
  JSON.parse(File.read(File.join(SPEC_DIR, *path), encoding: Encoding::UTF_8))
end

KEYS = spec_json("fixtures", "keys.json").freeze

# The shared playback server in conformance/server.js, started once for the whole run.
module ConformanceServer
  SCRIPT = File.expand_path("../spec/conformance/server.js", __dir__)

  class << self
    def url
      @url ||= start
    end

    # Queues responses and forgets the requests recorded so far.
    def load(responses)
      call(Net::HTTP::Post.new("/__load", "Content-Type" => "application/json"), JSON.generate(responses: responses))
    end

    # @return [Array<Hash>] method, path, headers (lower-cased names) and body of each request received
    def requests
      JSON.parse(call(Net::HTTP::Get.new("/__requests")))
    end

    private

    def start
      io = IO.popen(["node", SCRIPT], "r")
      line = io.gets or raise "conformance/server.js did not start"
      Minitest.after_run do
        Process.kill("TERM", io.pid)
        io.close
      end
      line[%r{http://127\.0\.0\.1:\d+}]
    end

    def call(request, body = nil)
      uri = URI(url)
      Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request, body).body }
    end
  end
end

# Shortcuts for tests that talk to the playback server.
module ServerHelpers
  private

  # A client pointed at the playback server, with the test keys.
  def conformance_client(**settings)
    WebsiteScreenshotWorld::Client.new(
      instant_snap_api_key: KEYS.fetch("instant_snap"),
      auto_schedule_api_key: KEYS.fetch("auto_schedule"),
      instant_snap_base_url: ConformanceServer.url,
      auto_schedule_base_url: ConformanceServer.url,
      **settings
    )
  end

  # A response for the playback server with a JSON body.
  def json_response(body, status: 200, headers: {})
    { status: status, headers: { "Content-Type" => "application/json" }.merge(headers), body: body }
  end

  def capture_body(**fields)
    body = spec_json("fixtures", "01-capture-minimal.json").fetch("responses").first.fetch("body")
    body.merge(fields.transform_keys(&:to_s))
  end
end
