# frozen_string_literal: true

module Checklist
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Checklist
  end
end
