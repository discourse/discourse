# frozen_string_literal: true

# name: jepsen
# about: Jepsen product plugin for Discourse
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/jepsen

enabled_site_setting :jepsen_enabled

module ::Jepsen
  PLUGIN_NAME = "jepsen"
end

require_relative "lib/jepsen/engine"

after_initialize { Discourse::Application.routes.append { mount Jepsen::Engine, at: "/jepsen" } }
