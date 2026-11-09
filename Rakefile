# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"

# The repository holds seven libraries, so each tags its releases with its own prefix (ruby-v0.1.0).
Bundler::GemHelper.tag_prefix = "ruby-"

Minitest::TestTask.create
RuboCop::RakeTask.new

task default: %i[test rubocop]
