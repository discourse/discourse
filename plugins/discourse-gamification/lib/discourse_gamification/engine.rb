# frozen_string_literal: true

module ::DiscourseGamification
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseGamification
  end
end
