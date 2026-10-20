# frozen_string_literal: true

# name: capybara
# about: TO BE DEFINED
# version: 0.2.0
# authors: Joffrey Jaffeux
# url: https://github.com/discourse/discourse-plugin-skeleton
# required_version: 2.7.0

enabled_site_setting :capybara_enabled

module ::DiscourseCapybara
  PLUGIN_NAME = "capybara"
end

require_relative "lib/discourse_capybara/engine"
