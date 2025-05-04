#!/usr/bin/env ruby
# frozen_string_literal: true
# rubocop:disable Discourse/NoChdir

require "fileutils"
require "tempfile"
require "open3"
require "json"

BUILD_INFO_FILE = "dist/BUILD_INFO.json"

Dir.chdir("#{__dir__}/../app/assets/javascripts/discourse")

def capture(*args)
  output, status = Open3.capture2(*args)
  raise "Command failed: #{args.inspect}" if status != 0
  output
end

# Returns a git tree-hash representing the current state of Discourse core.
# If the working directory is clean, it will match the tree hash (note: different to the commit hash) of the HEAD commit.
def core_tree_hash
  Tempfile.create do |f|
    f.close

    git_dir = capture("git", "rev-parse", "--git-dir").strip
    FileUtils.cp "#{git_dir}/index", f.path

    env = { "GIT_INDEX_FILE" => f.path }
    system(env, "git", "add", "-A", exception: true)
    return capture(env, "git", "write-tree").strip
  end
end

def node_heap_size_limit
  capture("node", "-e", "console.log(v8.getHeapStatistics().heap_size_limit/1024/1024)").to_f
end

def low_memory_environment?
  node_heap_size_limit < 2048
end

def resolved_ember_env
  ENV["EMBER_ENV"] || "production"
end

def build_info
  { "ember_env" => resolved_ember_env, "core_tree_hash" => core_tree_hash }
end

def existing_core_build_usable?
  if !File.exist?(BUILD_INFO_FILE)
    STDERR.puts "No existing build info file found."
    return false
  end

  existing = JSON.parse(File.read(BUILD_INFO_FILE))
  expected = build_info

  if existing == expected
    true
  else
    STDERR.puts <<~MSG
      Existing build is not reusable.
      - Existing: #{existing.inspect}
      - Current: #{expected.inspect}
    MSG
    false
  end
end

build_cmd = %w[pnpm ember build]
build_env = { "CI" => "1" }

if Etc.nprocessors > 2
  # Anything more than 2 doesn't seem to improve build times
  build_env["JOBS"] ||= "2"
end

if low_memory_environment?
  STDERR.puts "Node.js heap_size_limit is less than 2048MB. Setting --max-old-space-size=2048 and CHEAP_SOURCE_MAPS=1"
  build_env["NODE_OPTIONS"] = "--max_old_space_size=2048"
  build_env["CHEAP_SOURCE_MAPS"] = "1"
  build_env["JOBS"] = "1"
end

build_cmd << "-prod" if resolved_ember_env == "production"

if existing_core_build_usable?
  STDERR.puts "Reusing existing core ember build. Only building plugins..."
  build_env["SKIP_CORE_BUILD"] = "1"
  build_cmd << "-o" << "dist/_plugin_only_build"
  begin
    system(build_env, *build_cmd, exception: true)
    FileUtils.rm_rf("dist/assets/plugins")
    FileUtils.mv("dist/_plugin_only_build/assets/plugins", "dist/assets/plugins")
  ensure
    FileUtils.rm_rf("dist/_plugin_only_build")
  end
  STDERR.puts "Plugin build successfully integrated into dist"
else
  STDERR.puts "Running full core build..."
  system(build_env, *build_cmd, exception: true)
  File.write(BUILD_INFO_FILE, JSON.pretty_generate(build_info))
end
