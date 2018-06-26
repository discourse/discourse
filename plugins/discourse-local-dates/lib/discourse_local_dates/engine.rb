module ::DiscourseLocalDates
  PLUGIN_NAME = "discourse-local-dates"

  class Engine < ::Rails::Engine
    engine_name DiscourseLocalDates::PLUGIN_NAME
    isolate_namespace DiscourseLocalDates
  end
end
