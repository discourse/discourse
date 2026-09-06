# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ActorPolicy
      def initialize(exec_ctx)
        @exec_ctx = exec_ctx
      end

      def ensure_allowed!(actor, field:, item_index:, source:, purpose:)
        return true if actor.is_a?(DiscourseWorkflows::AnonymousActor)
        raise Discourse::InvalidAccess if actor.blank?
        raise Discourse::InvalidAccess if actor.staged?
        raise Discourse::InvalidAccess if actor.silenced?
        raise Discourse::InvalidAccess if actor.suspended?
        raise Discourse::InvalidAccess if !actor.active?

        true
      end
    end
  end
end
