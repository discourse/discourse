#! /usr/bin/env ruby
# frozen_string_literal: true

# It's important that our JS asset builds are reproducible so that users aren't forced to re-download
# assets after every deploy. This script runs two builds and compares the output to ensure that they
# are identical.

require "digest"

DIST_DIR = File.expand_path("#{__dir__}/../app/assets/javascripts/discourse/dist")

def collect_asset_info
  files =
    Dir.glob("**/*", base: DIST_DIR).reject { |path| File.directory? "#{DIST_DIR}/#{path}" }.sort
  puts "Found #{files.length} files"
  raise "No files found" if files.empty?
  digests = files.map { |file| Digest::MD5.file("#{DIST_DIR}/#{file}").hexdigest }
  { files: files, digests: digests }
end

puts "Running first build..."
system "#{__dir__}/../bin/yarn-app ember build -prod", exception: true
first_build_info = collect_asset_info

puts "Running second build..."
system "#{__dir__}/../bin/yarn-app ember build -prod", exception: true
second_build_info = collect_asset_info

puts nil, nil, "Comparing builds...", nil, nil

if first_build_info[:files] != second_build_info[:files]
  puts "Set of files is different"

  new_assets = first_build_info[:files].difference(second_build_info[:files])
  puts "Second build had additional assets: #{new_assets.inspect}"

  missing_assets = second_build_info[:files].difference(first_build_info[:files])
  puts "Second build was missing assets: #{missing_assets.inspect}"

  exit 1
else
  puts "Both builds produced the same file names"
end

if first_build_info[:digests] != second_build_info[:digests]
  puts "File digests are different"

  first_build_info[:files].each_with_index do |file, index|
    if first_build_info[:digests][index] != second_build_info[:digests][index]
      puts "File #{file} has different digest"
    end
  end

  exit 1
else
  puts "Files in both builds had identical digests"
end

puts nil, "Success!"
