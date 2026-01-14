# frozen_string_literal: true

module DiscourseSolved
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseSolved
    config.autoload_paths << File.join(config.root, "lib")
  end
end
