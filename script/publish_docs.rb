#!/usr/bin/env ruby
# frozen_string_literal: true

require "discourse_api"

key = ENV["META_DOCS_API_KEY"]

raise "No API key provided" if key.nil? || key.size < 1

client = DiscourseApi::Client.new("https://meta.discourse.org")
client.api_key = ENV["META_DOCS_API_KEY"]
client.api_username = "system"

# Add your doc files here!
# Make sure the post_id has been added to the Meta API key scope first.
DOCS = [
  # [ file path, meta post_id ]
  ["docs/INSTALL-cloud.md", 1_492_617],
]

DOCS.each do |path, post_id|
  puts "Publishing #{path} to https://meta.discourse.org/p/#{post_id}"
  content = File.read("#{__dir__}/../#{path}")
  content.gsub! /<!--\s*begin-docs-skip\s*-->.*?<!--\s*end-docs-skip\s*-->/m, ""
  client.edit_post(post_id, content)
  puts "... done"
end
