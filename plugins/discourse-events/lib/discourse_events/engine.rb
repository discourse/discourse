# frozen_string_literal: true

module DiscourseEvents
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseEvents

    initializer "discourse_events.autoloading", before: :setup_main_autoloader do
      directory = config.root.join("lib/discourse_events")
      Rails.autoloaders.main.push_dir(directory, namespace: DiscourseEvents)

      # These subtrees retain their explicit boot-time loading.
      Rails.autoloaders.main.ignore(
        directory.join("configuration"),
        directory.join("events"),
        directory.join("livestream"),
      )
    end
  end
end
