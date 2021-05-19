# frozen_string_literal: true

module ::Styleguide
  PLUGIN_NAME = "styleguide"

  class Engine < ::Rails::Engine
    engine_name Styleguide::PLUGIN_NAME
    isolate_namespace Styleguide
  end
end
