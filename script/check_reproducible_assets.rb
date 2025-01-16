#! /usr/bin/env ruby
# frozen_string_literal: true

# It's important that our JS asset builds are reproducible so that users aren't forced to re-download
# assets after every deploy. This script runs two builds and compares the output to ensure that they
# are identical.

require "digest"

DIST_DIR = File.expand_path("#{__dir__}/../app/assets/javascripts/discourse/dist")
DIST_1_DIR = File.expand_path("#{__dir__}/../app/assets/javascripts/discourse/dist1")

def collect_asset_info
  files =
    Dir.glob("**/*", base: DIST_DIR).reject { |path| File.directory? "#{DIST_DIR}/#{path}" }.sort
  puts "Found #{files.length} files"
  raise "No files found" if files.empty?
  digests = files.map { |file| Digest::MD5.file("#{DIST_DIR}/#{file}").hexdigest }
  sizes = files.map { |file| [file, File.size("#{DIST_DIR}/#{file}") / 8 / 1024] }.to_h
  { files: files, digests: digests, sizes: sizes }
end

def print_details(files, size_dict)
  files.each { |file| puts " - #{file} (#{size_dict[file]}kb)" }
end

puts "Running first build..."
system "cd #{__dir__}/.. && pnpm ember build -prod", exception: true
first_build_info = collect_asset_info
system "rm", "-rf", DIST_1_DIR, exception: true
system "mv", DIST_DIR, DIST_1_DIR, exception: true

puts "Running second build..."
Dir.chdir("#{__dir__}/../app/assets/javascripts/discourse") do # rubocop:disable Discourse/NoChdir
  system "/bin/bash",
         "-c",
         "shopt -s nullglob; rm -rf $TMPDIR/embroider $TMPDIR/.broccoli-* node_modules/.embroider",
         exception: true
end
system "cd #{__dir__}/.. && pnpm ember build -prod", exception: true
second_build_info = collect_asset_info

puts nil, nil, "Comparing builds...", nil, nil

if first_build_info[:files] != second_build_info[:files]
  puts "Set of files is different"

  new_assets = first_build_info[:files].difference(second_build_info[:files])
  puts "Second build had additional assets:"
  print_details(new_assets, first_build_info[:sizes])

  missing_assets = second_build_info[:files].difference(first_build_info[:files])
  puts "Second build was missing assets:"
  print_details(missing_assets, second_build_info[:sizes])

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
