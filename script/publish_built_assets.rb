#!/usr/bin/env ruby
# frozen_string_literal: true
# rubocop:disable Discourse/NoChdir

require "fileutils"
require_relative "../lib/version"
require "open3"

tmp_dir = "#{__dir__}/../tmp/prebuilt_asset_bundles"
FileUtils.mkdir_p(tmp_dir)

core_commit_hash = `git rev-parse HEAD`.strip
version_string = "v#{Discourse::VERSION::STRING}-#{core_commit_hash.slice(0, 8)}"
release_repo = "discourse/discourse-assets"

puts "Checking if release #{version_string} already exists in #{release_repo}..."

out, status =
  Open3.capture2e("gh", "--repo", release_repo, "release", "view", version_string, "--json", "name")
puts out

if status.success?
  puts "Release #{version_string} already exists in #{release_repo}. Exiting."
  exit 0
end

common_env = { "DISCOURSE_DOWNLOAD_PRE_BUILT_ASSETS" => "0", "LOAD_PLUGINS" => "0" }

Dir.chdir("#{__dir__}/../js/discourse")
FileUtils.rm_rf("dist")

system({ **common_env, "EMBER_ENV" => "production" }, "#{__dir__}/assemble_ember_build.rb")
FileUtils.rm_rf("dist/assets/plugins")
system("tar", "-czf", "#{tmp_dir}/production.tar.gz", "dist", exception: true)

FileUtils.rm_rf("dist")
system({ **common_env, "EMBER_ENV" => "development" }, "#{__dir__}/assemble_ember_build.rb")
FileUtils.rm_rf("dist/assets/plugins")
system("tar", "-czf", "#{tmp_dir}/development.tar.gz", "dist", exception: true)

puts "Creating release #{version_string} in #{release_repo}..."
system(
  "gh",
  "--repo",
  release_repo,
  "release",
  "create",
  version_string,
  "#{tmp_dir}/production.tar.gz",
  "#{tmp_dir}/development.tar.gz",
  "--title",
  version_string,
  "--notes",
  version_string,
  exception: true,
)

FileUtils.rm_rf(tmp_dir)
