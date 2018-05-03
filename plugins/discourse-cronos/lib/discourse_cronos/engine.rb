module ::DiscourseCronos
  PLUGIN_NAME = "discourse-cronos"

  class Engine < ::Rails::Engine
    engine_name DiscourseCronos::PLUGIN_NAME
    isolate_namespace DiscourseCronos
  end
end
