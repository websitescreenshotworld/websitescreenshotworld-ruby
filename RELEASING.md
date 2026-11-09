# Releasing

1. Move the "Unreleased" section of `CHANGELOG.md` under the new version and date.
2. Set the version: `VERSION` in `lib/websitescreenshotworld/version.rb`.
3. Commit, then tag that commit `v<version>`, such as `v0.1.1`, and push the tag.
4. The tag's workflow runs the tests again and publishes to RubyGems as `websitescreenshotworld`, through trusted publishing (environment `rubygems`).

The libraries for the other languages share the version number, so a change made in all of them is released at
the same version in each.
