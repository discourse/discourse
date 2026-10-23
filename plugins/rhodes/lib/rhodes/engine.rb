# frozen_string_literal: true

module Rhodes
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Rhodes
  end
end
