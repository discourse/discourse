# frozen_string_literal: true

module ::DiscourseHcaptcha
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseHcaptcha
    config.autoload_paths << File.join(config.root, "lib")
  end
end
