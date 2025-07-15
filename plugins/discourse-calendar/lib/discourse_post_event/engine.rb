# frozen_string_literal: true

module DiscoursePostEvent
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePostEvent
  end
end
