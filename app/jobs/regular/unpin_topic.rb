# frozen_string_literal: true

module Jobs
  class UnpinTopic < ::Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]

      return if topic_id.blank?

      topic = Topic.find_by(id: topic_id)
      return if topic.blank?

      pinned_globally = topic.pinned_globally
      was_pinned = topic.pinned_at.present?
      topic.update_pinned(false)

      # Unpinning manually goes through TopicStatusUpdater, which fires this event, but expiring doesn't.
      if was_pinned
        DiscourseEvent.trigger(
          :topic_status_updated,
          topic,
          pinned_globally ? "pinned_globally" : "pinned",
          false,
          acting_user: Discourse.system_user,
        )
      end
    end
  end
end
