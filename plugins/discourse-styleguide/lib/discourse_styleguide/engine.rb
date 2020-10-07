# frozen_string_literal: true

module ::DiscourseStyleguide
  PLUGIN_NAME = "discourse-styleguide"

  class Engine < ::Rails::Engine
    engine_name DiscourseStyleguide::PLUGIN_NAME
    isolate_namespace DiscourseStyleguide
  end
end
