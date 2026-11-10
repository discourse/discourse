# frozen_string_literal: true

module ::DiscourseRewind
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseRewind
    config.autoload_paths << File.join(config.root, "lib")
  end
end
