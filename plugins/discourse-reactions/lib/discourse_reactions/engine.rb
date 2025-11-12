# frozen_string_literal: true

module DiscourseReactions
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseReactions
  end
end
