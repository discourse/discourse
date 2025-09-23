# frozen_string_literal: true

module ::DiscourseTemplates
  class Engine < ::Rails::Engine
    engine_name DiscourseTemplates::PLUGIN_NAME
    isolate_namespace DiscourseTemplates
  end
end
