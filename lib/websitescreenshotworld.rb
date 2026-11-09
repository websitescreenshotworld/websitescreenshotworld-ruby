# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "securerandom"
require "tempfile"
require "time"
require "uri"

require_relative "websitescreenshotworld/version"
require_relative "websitescreenshotworld/tokens"
require_relative "websitescreenshotworld/errors"
require_relative "websitescreenshotworld/error_response"
require_relative "websitescreenshotworld/model"
require_relative "websitescreenshotworld/capture"
require_relative "websitescreenshotworld/capture_file"
require_relative "websitescreenshotworld/defaults"
require_relative "websitescreenshotworld/catalog"
require_relative "websitescreenshotworld/trigger_result"
require_relative "websitescreenshotworld/event_data"
require_relative "websitescreenshotworld/events"
require_relative "websitescreenshotworld/webhook"
require_relative "websitescreenshotworld/transport"
require_relative "websitescreenshotworld/service"
require_relative "websitescreenshotworld/instant_snap"
require_relative "websitescreenshotworld/auto_schedule"
require_relative "websitescreenshotworld/client"

# Client for the Website Screenshot World APIs: Instant Snap captures, Auto Schedule triggers and webhook
# verification. Start with {Client}.
module WebsiteScreenshotWorld
end
