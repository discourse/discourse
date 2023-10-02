# frozen_string_literal: true

module ::DiscourseAutomation
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAutomation
  end
end
