# frozen_string_literal: true

module Jepsen
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Jepsen
  end
end
