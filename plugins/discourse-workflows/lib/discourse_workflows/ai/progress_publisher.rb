# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    class ProgressPublisher
      CHANNEL_PREFIX = "/discourse-workflows/ai-authoring"
      MAX_BACKLOG_AGE = 5.minutes.to_i

      def self.publish(generation_id:, user:, status:, **payload)
        return if generation_id.blank? || user.blank?

        MessageBus.publish(
          "#{CHANNEL_PREFIX}/#{generation_id}",
          payload.merge(status: status, generation_id: generation_id),
          user_ids: [user.id],
          max_backlog_age: MAX_BACKLOG_AGE,
        )
      end
    end
  end
end
