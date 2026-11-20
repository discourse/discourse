# frozen_string_literal: true

module Live
  class Engine < ::Rails::Engine
    isolate_namespace Live
    engine_name PLUGIN_NAME
  end
end
