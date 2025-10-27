# frozen_string_literal: true

module DiscourseLocalDates
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseLocalDates
  end
end
