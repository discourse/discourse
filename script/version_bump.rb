#!/usr/bin/env ruby
#
# Increases the version. e.g., from 0.8.5 to 0.8.6.
# If you want to bump the minor or major version numbers, do it manually
# or edit lib/version.rb before running this file.

usage = <<-END

   Arguments:
     <version>: The new version. Must have at least 2 parts. Examples: 0.9.8, 0.10, 0.9.7.3
     no-commit: Don't commit the changes.
     push:      Push the commits to github. If used by itself without the version argument,
                it's assumed that the commit and tags are ready to be pushed.

  Example:

    To update the version in one step, and then push the commits in a second step:

      ruby script/version_bump.rb 0.9.7.3
      ruby script/version_bump.rb push

    To do everything in one step:

      ruby script/version_bump.rb 0.9.8 push

  END

VERSION_FILE_PATH = File.expand_path('../../lib/version.rb',  __FILE__)

if ARGV.length < 1
  puts usage
  exit 1
end

new_version = ARGV[0].split('.')
if new_version.length < (2) && !ARGV.include?('push')
  puts "First argument must be a version number with at least 2 parts. Examples: 0.9.8, 0.10, 0.9.7.3"
  exit 1
end

update_version_file = new_version.length >= 2

if update_version_file
  puts '', "New Version: #{new_version.join('.')}", "Updating #{VERSION_FILE_PATH}..."

  contents = ''
  tiny_version_bumped = false
  File.open(VERSION_FILE_PATH) do |f|
    contents = f.read
    ['MAJOR', 'MINOR', 'TINY', 'PRE'].each_with_index do |name, i|
      r = Regexp.new(name + '\s*=\s*(nil|[\d]+)')
      m = r.match(contents)
      v = new_version[i].to_i > 0 ? new_version[i] : (name == 'PRE' ? 'nil' : '0')
      contents.sub!(m[0], m[0].sub(m[1], v)) if m
    end
  end

  puts "Saving..."

  File.open(VERSION_FILE_PATH, 'w+') do |f|
    f.write(contents)
  end
end

require File.expand_path('../../lib/version',  __FILE__)

version = Discourse::VERSION::STRING
puts "New version is: #{version}"

unless ARGV.include?('no-commit') || !update_version_file
  puts "Committing..."

  `git add lib/version.rb`
  `git commit -m "Version bump to v#{version}"`
  sha = `git rev-parse HEAD`.strip
  `git tag -d latest-release`
  `git push origin :latest-release`
  `git tag -a v#{version} -m "version #{version}" #{sha}`
  `git tag -a latest-release -m "latest release" #{sha}`
end

if ARGV.include?('push')
  puts "Pushing..."

  `git push origin master`
  `git push origin v#{version}`
  `git push origin latest-release`
end

puts "Done", ''
