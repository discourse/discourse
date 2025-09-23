# frozen_string_literal: true

module ::DiscoursePoll
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePoll
  end

  class Error < StandardError
  end
end
