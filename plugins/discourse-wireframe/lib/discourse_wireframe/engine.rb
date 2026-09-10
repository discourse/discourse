# frozen_string_literal: true

module DiscourseWireframe
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseWireframe
    config.autoload_paths << File.join(config.root, "lib")
  end
end
