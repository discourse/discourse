# frozen_string_literal: true

module Styleguide
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Styleguide
  end
end
