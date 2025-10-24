# frozen_string_literal: true

module DiscoursePolicy
  HAS_POLICY = "HasPolicy"
  POLICY_USER_DEFAULT_LIMIT = 25

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePolicy
  end
end
