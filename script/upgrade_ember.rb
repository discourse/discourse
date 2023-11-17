#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

Dir.chdir("#{__dir__}/../app/assets/javascripts") do # rubocop:disable Discourse/NoChdir because this is not part of the app
  Dir.glob("*/package.json") do |file|
    parsed = JSON.parse(File.read(file))
    if parsed["dependencies"]&.key?("ember-source")
      system("yarn --cwd #{File.dirname(file)} add ember-source@5.4.0", exception: true)
    elsif parsed["devDependencies"]&.key?("ember-source")
      system("yarn --cwd #{File.dirname(file)} add --dev ember-source@5.4.0", exception: true)
    end
  end
end
