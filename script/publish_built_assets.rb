#!/usr/bin/env ruby
# frozen_string_literal: true
# rubocop:disable Discourse/NoChdir

require "fileutils"
require_relative "../lib/version"
require "open3"
require "parallel"
require "etc"

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

COMMON_ENV = {
  "DISCOURSE_DOWNLOAD_PRE_BUILT_ASSETS" => "0",
  "LOAD_PLUGINS" => "1",
  "ROLLUP_PLUGIN_COMPILER" => "1",
  "SKIP_DB_AND_REDIS" => "1",
}

Dir.chdir("#{__dir__}/..")

TMP_DIR = "./tmp/prebuilt_asset_bundles"
FileUtils.rm_rf(TMP_DIR)
FileUtils.mkdir_p(TMP_DIR)

def bundle(name:, env:, compress:)
  FileUtils.rm_rf("frontend/discourse/dist")
  FileUtils.rm_rf("app/assets/generated")

  system({ **COMMON_ENV, **env }, "#{__dir__}/assemble_ember_build.rb")

  out_dir = "#{TMP_DIR}/#{name}"
  FileUtils.mkdir_p(out_dir)
  FileUtils.mv("frontend/discourse/dist", "#{out_dir}/core")
  FileUtils.mv("app/assets/generated", "#{out_dir}/plugins")

  if compress
    files = Dir.glob("#{out_dir}/**/*.js")
    Parallel.map(files, in_threads: 4) do |file|
      start = Time.now

      system("brotli", "-f", "--quality=11", "-o", "#{file}.br", file, exception: true)
      IO.popen(["gzip", "-f", "-9", "-c", file], "rb") { |io| File.write("#{file}.gz", io.read) }
      raise "gzip failed for #{file}" unless $?.success?

      puts "Compressed #{file} in #{(Time.now - start).round(2)}s"
    end
  end

  system(
    "tar",
    "-czf",
    "#{TMP_DIR}/#{name}.tar.gz",
    "-C",
    out_dir,
    "core",
    "plugins",
    exception: true,
  )
end

bundle(
  name: "production",
  env: {
    "EMBER_ENV" => "production",
    "RAILS_ENV" => "production",
  },
  compress: true,
)
bundle(
  name: "development",
  env: {
    "EMBER_ENV" => "development",
    "RAILS_ENV" => "development",
  },
  compress: false,
)

puts "Creating release #{version_string} in #{release_repo}..."
system(
  "gh",
  "--repo",
  release_repo,
  "release",
  "create",
  version_string,
  "#{TMP_DIR}/production.tar.gz",
  "#{TMP_DIR}/development.tar.gz",
  "--title",
  version_string,
  "--notes",
  version_string,
  exception: true,
)

FileUtils.rm_rf(TMP_DIR)
