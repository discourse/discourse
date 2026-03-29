# frozen_string_literal: true

module DiscourseBoosts
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseBoosts
    config.autoload_paths << File.join(config.root, "lib")
  end
end
