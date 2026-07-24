# frozen_string_literal: true

module DiscourseCaptcha
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseCaptcha
    config.autoload_paths << File.join(config.root, "lib")
  end
end
