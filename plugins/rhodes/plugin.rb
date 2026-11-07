# frozen_string_literal: true

# name: rhodes
# about: Rhodes product plugin for Discourse
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/rhodes

enabled_site_setting :rhodes_enabled

module ::Rhodes
  PLUGIN_NAME = "rhodes"
end

require_relative "lib/rhodes/engine"

after_initialize { Discourse::Application.routes.append { mount Rhodes::Engine, at: "/rhodes" } }
