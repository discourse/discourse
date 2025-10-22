# frozen_string_literal: true

module DiscourseCakeday
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseCakeday
  end
end
