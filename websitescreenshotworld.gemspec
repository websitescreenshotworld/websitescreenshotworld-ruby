# frozen_string_literal: true

require_relative "lib/websitescreenshotworld/version"

Gem::Specification.new do |spec|
  spec.name = "websitescreenshotworld"
  spec.version = WebsiteScreenshotWorld::VERSION
  spec.authors = ["Silhouettec Solutions Private Limited"]
  spec.email = ["support@websitescreenshotworld.com"]

  spec.summary = "Ruby client for the Website Screenshot World Instant Snap and Auto Schedule APIs."
  spec.description = "Capture web pages as images, videos or PDFs with Instant Snap, trigger scheduled " \
                     "captures with Auto Schedule, and verify Website Screenshot World webhooks."
  spec.homepage = "https://websitescreenshotworld.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  repository = "https://github.com/websitescreenshotworld/websitescreenshotworld-ruby"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => repository,
    "changelog_uri" => "#{repository}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{repository}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ["lib"]
end
