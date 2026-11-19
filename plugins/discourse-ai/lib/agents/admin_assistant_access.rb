# frozen_string_literal: true

module DiscourseAi
  module Agents
    module AdminAssistantAccess
      Request = Data.define(:feature, :user, :phase)
      Result = Data.define(:allowed, :message)

      class Decision
        attr_reader :message

        def initialize
          @allowed = true
        end

        def allowed?
          @allowed
        end

        def deny!(message = nil)
          @allowed = false
          @message ||= message
          self
        end
      end

      def self.check(feature:, user:, phase:)
        decision = Decision.new
        request = Request.new(feature: feature, user: user, phase: phase)
        DiscoursePluginRegistry.apply_modifier(:admin_assistant_feature_access, decision, request)

        Result.new(allowed: decision.allowed?, message: decision.message)
      end
    end
  end
end
