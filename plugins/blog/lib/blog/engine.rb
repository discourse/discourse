# frozen_string_literal: true

module ::Blog
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Blog
    # The plugin loader already registers these tasks.
    paths["lib/tasks"] = []
    config.autoload_paths << File.join(config.root, "lib")
  end
end
