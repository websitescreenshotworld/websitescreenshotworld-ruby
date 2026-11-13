# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.2 - 2026-11-13

The first version on RubyGems. The library is the same as 0.1.0; 0.1.0 and 0.1.1 were tagged but never published.

### Fixed

- A test compared the User-Agent with a hard-coded 0.1.0, so the 0.1.1 release stopped at the test step. It now
  reads the version from `WebsiteScreenshotWorld::VERSION`.

## 0.1.1 - 2026-11-13

Tagged but not published (see 0.1.2).

### Fixed

- Publishing: the release job builds and pushes the gem itself instead of running `rake release`, which tried to
  create and push a `ruby-v` tag left over from the old multi-library repository.

## 0.1.0 - 2026-11-09

The first release.

### Added

- `WebsiteScreenshotWorld::Client`, one client for both products, with keys read from
  `WSW_INSTANT_SNAP_API_KEY` and `WSW_AUTO_SCHEDULE_API_KEY` by default.
- Instant Snap: `capture`, `capture_file` (streamed, or buffered to a `Tempfile`), `capture_to_bucket`,
  `get`, `download`, `defaults` and `catalog`, taking every capture option of the API as keyword arguments.
- Auto Schedule: `trigger_now`.
- The `press_escape` capture option, and the `sitemap_schedule_not_triggerable` error code (an
  `InvalidRequestError`: a sitemap schedule runs only on its schedule), from API version 1.1.0.
- `WebsiteScreenshotWorld::Webhook.verify`, which checks the `X-WSW-Signature` header and returns a typed
  event for each webhook type, or `UnknownEvent` for types added later.
- Immutable `Data` results with `Time` fields and the original JSON in `#raw`.
- One error class per kind of refusal under `WebsiteScreenshotWorld::Error`, plus `ConnectionError`.
- Automatic retries of rate limits, busy or unavailable services and connection failures, with a random
  `Idempotency-Key` per capture so a retry never captures twice, and timeouts that cover the whole call, retries
  included.
- Redirects are never followed, so the API key is never sent to another host; a 3xx answer is raised as an error.
- Async Instant Snap captures: `submit` and `submit_to_bucket` (answered at once with the capture
  `queued`) and `wait`, which polls `get` until the capture has finished or its `timeout_seconds` run out;
  the `timeout:` option of an async capture (30 to 300 seconds of browser time); the `CaptureStatus::QUEUED`
  and `CaptureStatus::RUNNING` statuses; and the `queue_full` (`RateLimitError`, not retried) and
  `capture_expired` (`CaptureError`) error codes.
