# frozen_string_literal: true

module DiscourseEvents
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseEvents
  end
end
