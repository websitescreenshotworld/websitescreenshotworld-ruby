# Website Screenshot World for Ruby

The Ruby client for [Website Screenshot World](https://websitescreenshotworld.com): capture web pages as
images, videos and PDFs with **Instant Snap**, start scheduled captures with **Auto Schedule**, and verify
the webhooks both send.

It has no runtime dependencies beyond the Ruby standard library.

## Install

```sh
bundle add websitescreenshotworld
```

or `gem install websitescreenshotworld`.

## Quick start

### Instant Snap

```ruby
require "websitescreenshotworld"

# Reads WSW_INSTANT_SNAP_API_KEY and WSW_AUTO_SCHEDULE_API_KEY from the environment.
client = WebsiteScreenshotWorld::Client.new

capture = client.instant_snap.capture(
  url: "https://example.com",
  format: "webp",
  viewport: { width: 1440, height: 900 },
  scroll_mode: "scroll",
  block_ads: false
)

capture.id           # => "3f6c2a1e-..."
capture.status       # => "succeeded"
capture.captured_at  # => 2026-09-26 10:30:04.512 UTC (a Time)
capture.download_url # valid for 60 minutes
```

Options are keyword arguments with the API's own names; nested blocks are hashes. An option you leave out
is not sent and takes the server's default, while `false`, `0` and `""` are sent as given. The keys of
`headers:` and `cookies:` are sent exactly as you write them. Every option is listed in
`WebsiteScreenshotWorld::InstantSnap::CAPTURE_OPTIONS`, and a misspelt one raises `ArgumentError` before
anything is sent.

Constants name the known values of each token, for example `WebsiteScreenshotWorld::Format::WEBP` or
`WebsiteScreenshotWorld::CaptureStatus::SUCCEEDED`. Tokens are plain strings, so a value added to the API
later still comes through.

### Auto Schedule

```ruby
result = client.auto_schedule.trigger_now("7d4e2b1a-6c5f-4a3e-9d8c-2b1a0f9e8d7c")

result.status       # => "triggered", or "already_pending" if a capture was already queued
result.triggered_at # => a Time
```

The web page is set up in the dashboard. Its capture arrives later by [webhook](#webhooks), where the
same id is called `schedule_id`.

## Saving the file with `capture_file`

`capture_file` answers with the file itself (up to 64 MB) and its metadata. With a block, the body streams
straight from the connection and is never held in memory:

```ruby
client.instant_snap.capture_file(url: "https://example.com", format: "png") do |file|
  file.filename   # => "3f6c2a1e-....png"
  file.width      # => 1920
  file.sha256     # => lowercase hex digest of the body
  file.save("page.png")
end
```

`save` also takes an open IO, such as a socket or an upload stream. `read` returns the bytes as a String
and `each_chunk` yields them as they arrive. The body can be read once.

Without a block, the body is buffered to a `Tempfile` first, so the file outlives the connection. Close it
when you are done to delete the temporary copy:

```ruby
file = client.instant_snap.capture_file(url: "https://example.com")
begin
  file.path # the Tempfile's path
  file.save("page.png")
ensure
  file.close
end
```

## Uploading to a bucket

`capture_to_bucket` uploads the file to your S3-compatible bucket instead of keeping it:

```ruby
capture = client.instant_snap.capture_to_bucket(
  url: "https://example.com",
  s3_delivery: {
    access_key_id: ENV.fetch("S3_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("S3_SECRET_ACCESS_KEY"),
    bucket: "captures",
    region: "eu-west-2",
    key_prefix: "site/",
    wait_for_sync: true
  }
)

capture.s3_delivery.status # => "completed", "in_progress", ...
capture.s3_delivery.key    # => the object key, once known
```

Use `endpoint_url:` (and `force_path_style: true` where needed) for providers other than AWS.

## Async captures

`submit` answers at once, before the capture runs, with the capture in status `queued`; it then goes
`running`, and ends `succeeded` or `failed`. `wait` reads it with `get` every `poll_interval_seconds`
(default 3) until it has finished, and returns it:

```ruby
queued = client.instant_snap.submit(url: "https://example.com", format: "webp", timeout: 240)
queued.status # => "queued"

capture = client.instant_snap.wait(queued) # or wait(queued.id), with timeout_seconds: 360 by default
if capture.status == WebsiteScreenshotWorld::CaptureStatus::SUCCEEDED
  client.instant_snap.download(capture, "page.webp")
end
```

If `timeout_seconds` runs out first, `wait` returns the capture as last read, still `queued` or `running`,
rather than raising, so you can wait again. The `capture.succeeded` and `capture.failed` [webhooks](#webhooks)
tell you without polling.

`submit_to_bucket` is the async `capture_to_bucket`:

```ruby
queued = client.instant_snap.submit_to_bucket(
  url: "https://example.com",
  s3_delivery: { access_key_id: "...", secret_access_key: "...", bucket: "captures", region: "eu-west-2" }
)
capture = client.instant_snap.wait(queued.id, poll_interval_seconds: 5)
capture.s3_delivery.status # => "completed", ...
```

- On `submit` and `submit_to_bucket`, `timeout:` is the browser time the capture may use, 30 to 300 seconds
  (the server uses 120 when you leave it out). The request itself is quick and uses the client's ordinary
  `timeout` (30 seconds by default). On the other capture methods `timeout:` is the call's own timeout, as in
  [Timeouts](#timeouts).
- A capture still queued 15 minutes after it was accepted ends `failed` with `capture_expired`, and is not
  charged.
- When your organization already has as many async captures waiting or running as it may, `submit` raises
  `RateLimitError` with `error_code` `queue_full` and `retry_after_seconds`. It is not retried, since a retry
  would meet the same queue.

## Reading a capture back

```ruby
capture = client.instant_snap.get("3f6c2a1e-9b8d-4c7e-a5f4-1d2e3c4b5a69")

# get reissues download_url; download streams it to a path or an IO.
client.instant_snap.download(capture, "page.png")
client.instant_snap.download(capture.page_source, "page.html") if capture.page_source
```

Files are kept for 24 hours (`capture.expires_at`). The API key is not sent to the download host.

`client.instant_snap.defaults` returns the values a capture takes for options it does not send (no key
needed), and `client.instant_snap.catalog` lists the accepted `emulated_device` and `proxy: { country: }`
values.

Every result is an immutable `Data` object. Dates are `Time` objects in UTC, and `raw` holds the JSON
object as the API sent it, including fields added after this version of the gem.

## Errors and retries

Every error inherits from `WebsiteScreenshotWorld::Error`, which carries `error_code`, `message`,
`http_status`, `retry_after_seconds` and the raw response `body`. Switch on `error_code`, never on the
status or the message.

| Class | Raised for |
|---|---|
| `AuthenticationError` | `api_key_invalid`, or a key that was never given |
| `InvalidRequestError` | `validation_failed`, `s3_destination_invalid`, `web_page_id_invalid`, `idempotency_key_reused`, `sitemap_schedule_not_triggerable` |
| `PlanLimitError` | `quota_exhausted`, `feature_not_available`, `no_trigger_allowance`, `forbidden` |
| `NotFoundError` | `capture_not_found`, `web_page_not_found`, `not_found` |
| `RateLimitError` | `rate_limited`, `queue_full` |
| `CaptureError` | `capture_failed`, `capture_timeout`, `payload_too_large`, `capture_expired` |
| `ServiceError` | `capture_busy`, `service_unavailable`, `internal_error`, `request_cancelled`, `idempotency_key_in_use` |
| `ConnectionError` | no answer: the connection failed or broke, or the timeout ran out (see `cause`) |
| `SignatureVerificationError` | a webhook signature that does not verify |
| `Error` | a code this version does not know yet |

```ruby
begin
  client.instant_snap.capture(url: "https://example.com")
rescue WebsiteScreenshotWorld::CaptureError => e
  # The website refused or was too slow. Nothing was charged.
  warn "#{e.error_code}: #{e.message}"
rescue WebsiteScreenshotWorld::PlanLimitError => e
  warn "Plan limit: #{e.error_code}"
rescue WebsiteScreenshotWorld::Error => e
  warn "#{e.class}: #{e.message} (HTTP #{e.http_status})"
end
```

`rate_limited`, `capture_busy`, `service_unavailable`, `idempotency_key_in_use` and connection failures
are retried up to twice before the error is raised. The wait is the `retry_after_seconds` the API sends
(or its `Retry-After` header), capped at 60 seconds, or else 0.5 and then 1 second with some random jitter.
Nothing else is retried, including `capture_failed`, `capture_timeout` and `queue_full`.

## Idempotency keys

Every capture sends an `Idempotency-Key`, and its retries reuse it, so a retry never captures twice. The
gem makes a random one per call. Pass your own to make a call safe to repeat across processes, for
example from a background job:

```ruby
capture = client.instant_snap.capture(url: "https://example.com", idempotency_key: "order-1234-hero")
capture.idempotent_replayed? # => true when this answers an earlier request with the same key
```

A key is remembered for 24 hours. Reusing it with a different body, or after a `capture_file` call (whose
file is not kept), raises `InvalidRequestError` with `idempotency_key_reused`.

## Timeouts

A capture may run for up to 120 seconds on the server, so capture calls and downloads wait up to 180
seconds by default and every other call, `submit` and `submit_to_bucket` included, 30 seconds. A timeout covers the whole call, retries included: a
wait that would run past it is not started, and the last error is raised at once.

```ruby
client = WebsiteScreenshotWorld::Client.new(capture_timeout: 240, timeout: 10)

# Per call, on capture, capture_file, capture_to_bucket and download:
client.instant_snap.capture(url: "https://example.com", timeout: 60)
```

Redirects are never followed, so the API key is never sent to another host. Neither the API nor a download link
redirects, so a `3xx` answer is raised as an error.

## Webhooks

Deliveries are signed with the `X-WSW-Signature` header. `Webhook.verify` checks the signature and the
timestamp (within 300 seconds by default) and returns a typed event:

| `type` | Class | `data` |
|---|---|---|
| `capture.succeeded` | `CaptureSucceededEvent` | `Capture` (Instant Snap) or `ScheduledCapture` (Auto Schedule) |
| `capture.failed` | `CaptureFailedEvent` | `Capture` or `ScheduledCapture` |
| `delivery.completed` | `DeliveryCompletedEvent` | `ScheduledCapture` with `destinations` |
| `capture.changed` | `CaptureChangedEvent` | `ScheduledCapture` with `change_percent` |
| `schedule.paused` | `SchedulePausedEvent` | `SchedulePause` |
| `sitemap_run.completed` | `SitemapRunCompletedEvent` | `SitemapRun` |
| `ping` | `PingEvent` | `Ping` |
| anything newer | `UnknownEvent` | the raw `Hash` |

All of them inherit from `WebsiteScreenshotWorld::Event`, which has `id`, `type`, `created_at`, `product`
and `data`.

**Pass the body exactly as it arrived.** Parsing the JSON and serialising it again changes the bytes and the
signature no longer matches. Each framework below reads the raw body.

### Rails

```ruby
class WebsiteScreenshotWorldWebhooksController < ActionController::API
  def create
    event = WebsiteScreenshotWorld::Webhook.verify(
      request.raw_post,
      request.headers["X-WSW-Signature"],
      ENV.fetch("WSW_WEBHOOK_SECRET")
    )

    case event
    when WebsiteScreenshotWorld::CaptureSucceededEvent
      Rails.logger.info("Capture #{event.data.id} succeeded")
    when WebsiteScreenshotWorld::SchedulePausedEvent
      Rails.logger.warn("Schedule #{event.data.schedule_name} paused: #{event.data.reason}")
    end

    head :ok
  rescue WebsiteScreenshotWorld::SignatureVerificationError
    head :bad_request
  end
end
```

### Sinatra

```ruby
post "/webhooks/websitescreenshotworld" do
  request.body.rewind
  event = WebsiteScreenshotWorld::Webhook.verify(
    request.body.read,
    request.env["HTTP_X_WSW_SIGNATURE"],
    ENV.fetch("WSW_WEBHOOK_SECRET")
  )
  logger.info("Received #{event.type} #{event.id}")
  200
rescue WebsiteScreenshotWorld::SignatureVerificationError
  400
end
```

### Rack

```ruby
class WebsiteScreenshotWorldWebhook
  def call(env)
    request = Rack::Request.new(env)
    event = WebsiteScreenshotWorld::Webhook.verify(
      request.body.read,
      env["HTTP_X_WSW_SIGNATURE"],
      ENV.fetch("WSW_WEBHOOK_SECRET")
    )
    warn "Received #{event.type} #{event.id}"
    [200, {}, []]
  rescue WebsiteScreenshotWorld::SignatureVerificationError
    [400, {}, []]
  end
end
```

Events also work with pattern matching:

```ruby
case event
in { type: "capture.changed", data: { change_percent:, url: } } if change_percent > 10
  puts "#{url} changed by #{change_percent}%"
in WebsiteScreenshotWorld::UnknownEvent
  # A type added after this version of the gem.
else
end
```

## Configuration

| Keyword for `Client.new` | Default |
|---|---|
| `instant_snap_api_key` | `ENV["WSW_INSTANT_SNAP_API_KEY"]` |
| `auto_schedule_api_key` | `ENV["WSW_AUTO_SCHEDULE_API_KEY"]` |
| `instant_snap_base_url` | `https://api.websitescreenshotworld.com` |
| `auto_schedule_base_url` | `https://autoapi.websitescreenshotworld.com` |
| `capture_timeout` | `180` seconds, for captures and downloads |
| `timeout` | `30` seconds, for everything else, including `submit` and `submit_to_bucket` |
| `max_retries` | `2` (so at most 3 attempts); `0` turns retrying off |

Either key may be left out. Calling a product whose key is missing raises `AuthenticationError` before
anything is sent. A client holds no open connection and is safe to share between threads.

Requests go through `Net::HTTP`, which honours the `https_proxy` and `no_proxy` environment variables.

## Supported Ruby versions

Ruby 3.2 and later. CI runs on 3.2 and 3.4.

## Development

The test suite plays the shared cases in `spec/` back through `spec/conformance/server.js`, so it needs
Node.js 22 or later. `spec/` is the [websitescreenshotworld-spec](https://github.com/websitescreenshotworld/websitescreenshotworld-spec) submodule: clone with `git clone --recurse-submodules`, or run `git submodule update --init` in an existing clone.

```sh
bundle install
bundle exec rake   # tests, then RuboCop
```

## License

MIT. See [LICENSE](LICENSE).
