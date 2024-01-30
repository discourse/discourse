#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"

v = ARGV[0]

raise "Unexpected version #{v}" if !%w[3 5].include?(v)

# rubocop:disable Discourse/NoChdir
Dir.chdir("#{__dir__}/../app/assets/javascripts") do
  FileUtils.rm("package.json")
  FileUtils.rm("yarn.lock")

  File.symlink("package-ember#{v}.json", "package.json")
  File.symlink("yarn-ember#{v}.lock", "yarn.lock")
end
