# frozen_string_literal: true

module ::DiscourseSubscriptions
  class Engine < ::Rails::Engine
    engine_name "discourse-subscriptions"
    isolate_namespace DiscourseSubscriptions
  end
end
