# frozen_string_literal: true

module DiscourseRssPolling
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseRssPolling

    config.to_prepare do
      Dir[
        File.expand_path(File.join("..", "..", "..", "app", "jobs", "**", "*.rb"), __FILE__)
      ].each { |job| require_dependency job }
    end
  end
end
