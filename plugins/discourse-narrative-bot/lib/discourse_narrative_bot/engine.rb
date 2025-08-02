# frozen_string_literal: true

module DiscourseNarrativeBot
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseNarrativeBot
    config.autoload_paths << File.join(config.root, "lib")
  end
end
