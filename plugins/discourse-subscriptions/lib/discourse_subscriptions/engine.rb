# frozen_string_literal: true

module DiscourseSubscriptions
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseSubscriptions
  end
end
