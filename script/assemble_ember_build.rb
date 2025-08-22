#!/usr/bin/env ruby
# frozen_string_literal: true
# rubocop:disable Discourse/NoChdir

require "fileutils"
require "tempfile"
require "open3"
require "json"
require "time"

require_relative "../lib/version"

DOWNLOAD_PRE_BUILT_ASSETS = ENV["DISCOURSE_DOWNLOAD_PRE_BUILT_ASSETS"] != "0"
DOWNLOAD_TEMP_FILE = "#{__dir__}/../tmp/assets.tar.gz"

PRE_BUILD_ROOT = "https://get.discourse.org/discourse-assets"

JS_SOURCE_PATHS = %w[app/assets/javascripts package.json pnpm-lock.yaml]

EMBER_APP_DIR = "app/assets/javascripts/discourse"
BUILD_INFO_FILE = "#{EMBER_APP_DIR}/dist/BUILD_INFO.json"

Dir.chdir("#{__dir__}/..")

def capture(*args)
  output, status = Open3.capture2(*args)
  raise "Command failed: #{args.inspect}" if status != 0
  output
end

def log(message)
  STDERR.puts "[assemble_ember_build] #{message}"
end

# Returns a git tree-hash representing the current state of Discourse core JS source paths.
# Only files in JS_SOURCE_PATHS are included in the tree hash.
def core_tree_hash
  Tempfile.create do |f|
    f.close

    git_dir = capture("git", "rev-parse", "--git-dir").strip
    FileUtils.cp "#{git_dir}/index", f.path

    env = { "GIT_INDEX_FILE" => f.path }

    # Remove all files from the index, then add only JS_SOURCE_PATHS
    system(env, "git", "rm", "-r", "--cached", ".", "--quiet", exception: true)
    system(env, "git", "add", *JS_SOURCE_PATHS, exception: true)

    capture(env, "git", "write-tree").strip
  end
end

def node_heap_size_limit
  capture("node", "-e", "console.log(v8.getHeapStatistics().heap_size_limit/1024/1024)").to_f
end

def low_memory_environment?
  node_heap_size_limit < 2048
end

def resolved_ember_env
  ENV["EMBER_ENV"] || "development"
end

def build_info
  { "ember_env" => resolved_ember_env, "core_tree_hash" => core_tree_hash }
end

def existing_core_build_usable?
  if !File.exist?(BUILD_INFO_FILE)
    log "No existing build info file found."
    return false
  end

  existing = JSON.parse(File.read(BUILD_INFO_FILE))
  expected = build_info

  if existing == expected
    true
  else
    log <<~MSG
      Existing build is not reusable.
      - Existing: #{existing.inspect}
      - Current: #{expected.inspect}
    MSG
    false
  end
end

def download_prebuild_assets!
  return false if !DOWNLOAD_PRE_BUILT_ASSETS

  status_output = capture("git", "status", "--porcelain", *JS_SOURCE_PATHS).strip
  git_is_clean = status_output.empty?
  if !git_is_clean
    log "JS-related files in the git working directory have been changed. Skipping download of prebuilt assets."
    return false
  end

  core_commit_hash = capture("git", "rev-parse", "HEAD").strip
  version_string = "#{Discourse::VERSION::STRING}-#{core_commit_hash.slice(0, 8)}"

  url = "#{PRE_BUILD_ROOT}/#{version_string}/#{resolved_ember_env}.tar.gz"
  puts "Fetching and extracting #{url}..."

  begin
    system("curl", "--fail-with-body", "-L", url, "-o", DOWNLOAD_TEMP_FILE, exception: true)
  rescue RuntimeError => e
    log "Failed to download prebuilt assets: #{e.message}"
    return false
  end

  FileUtils.rm_rf("#{EMBER_APP_DIR}/dist")
  FileUtils.mkdir_p("#{EMBER_APP_DIR}/dist")
  begin
    system(
      "tar",
      "--strip-components=1",
      "-xzf",
      DOWNLOAD_TEMP_FILE,
      "-C",
      "#{EMBER_APP_DIR}/dist",
      exception: true,
    )
  rescue RuntimeError => e
    log "Failed to extract prebuilt assets: #{e.message}"
    return false
  end

  puts "Prebuilt assets downloaded and extracted successfully."
  true
ensure
  FileUtils.rm_f(DOWNLOAD_TEMP_FILE) if File.exist?(DOWNLOAD_TEMP_FILE)
end

build_cmd = %w[pnpm ember build]
build_env = { "CI" => "1" }

if Etc.nprocessors > 2
  # Anything more than 2 doesn't seem to improve build times
  build_env["JOBS"] ||= "2"
end

if low_memory_environment?
  log "Node.js heap_size_limit is less than 2048MB. Setting --max-old-space-size=2048 and CHEAP_SOURCE_MAPS=1"
  build_env["NODE_OPTIONS"] = "--max_old_space_size=2048"
  build_env["CHEAP_SOURCE_MAPS"] = "1"
  build_env["JOBS"] = "1"
end

build_cmd << "-prod" if resolved_ember_env == "production"

core_build_reusable =
  existing_core_build_usable? || (download_prebuild_assets! && existing_core_build_usable?)

if core_build_reusable && ENV["LOAD_PLUGINS"] == "0"
  log "Reusing existing core ember build. Plugins not loaded. All done."
elsif core_build_reusable
  log "Reusing existing core ember build. Only building plugins..."
  build_env["SKIP_CORE_BUILD"] = "1"
  build_cmd << "-o" << "dist/_plugin_only_build"
  begin
    system(build_env, *build_cmd, exception: true, chdir: EMBER_APP_DIR)
    FileUtils.rm_rf("#{EMBER_APP_DIR}/dist/assets/plugins")
    FileUtils.mv(
      "#{EMBER_APP_DIR}/dist/_plugin_only_build/assets/plugins",
      "#{EMBER_APP_DIR}/dist/assets/plugins",
    )
  ensure
    FileUtils.rm_rf("#{EMBER_APP_DIR}/dist/_plugin_only_build")
  end
  log "Plugin build successfully integrated into dist"
else
  log "Running full core build..."
  system(build_env, *build_cmd, exception: true, chdir: EMBER_APP_DIR)
  File.write(BUILD_INFO_FILE, JSON.pretty_generate(build_info))
end
