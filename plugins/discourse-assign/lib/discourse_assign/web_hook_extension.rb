# frozen_string_literal: true

module DiscourseAssign
  module WebHookExtension
    extend ActiveSupport::Concern

    class_methods do
      def enqueue_assign_hooks(event, payload)
        return unless active_web_hooks(event).exists?
        enqueue_hooks(:assign, event, payload: payload)
      end
    end
  end
end
