# frozen_string_literal: true

module ::DiscoursePolicy
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePolicy
  end
end
