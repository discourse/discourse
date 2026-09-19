# frozen_string_literal: true

module Voice
  class Engine < ::Rails::Engine
    isolate_namespace Voice
    engine_name PLUGIN_NAME
  end
end
