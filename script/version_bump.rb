#!/usr/bin/env ruby
#
# Increases the version. e.g., from 0.8.5 to 0.8.6.
# If you want to bump the minor or major version numbers, do it manually
# or edit lib/version.rb before running this file.
#
# Optional arguments:
#   no-commit: Don't commit the file changes
#   no-push:   Don't push the commits to github. no-commit implies no-push too.

VERSION_FILE_PATH = File.expand_path('../../lib/version.rb',  __FILE__)

puts '', "Updating #{VERSION_FILE_PATH}..."

contents = ''
tiny_version_bumped = false
File.open(VERSION_FILE_PATH) do |f|
  line = f.read
  m = /TINY\s*=\s*([\d]+)/.match(line)
  tiny_version_bumped = true if m
  contents += m ? line.sub(m[0], m[0].sub(m[1], (m[1].to_i + 1).to_s)) : line
end

unless tiny_version_bumped
  puts "ERROR: couldn't update lib/version.rb. Is it missing the TINY constant?"
  exit 1
end

puts "Saving..."

File.open(VERSION_FILE_PATH, 'w+') do |f|
  f.write(contents)
end

require File.expand_path('../../lib/version',  __FILE__)

version = Discourse::VERSION::STRING
puts "New version is: #{version}"

puts ARGV

unless ARGV.include?('no-commit')
  puts "Commiting..."

  `git add lib/version.rb`
  `git commit -m "Version bump to v#{version}"`
  sha = `git rev-parse HEAD`.strip
  `git tag -a v#{version} -m "version #{version}" #{sha}`

  unless ARGV.include?('no-push')
    puts "Pushing..."
    `git push origin master`
    `git push origin v#{version}`
  end
end

puts "Done",''
