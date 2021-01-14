# frozen_string_literal: true

module Jobs
  class DeleteTopic < ::Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])
      return if !topic_timer&.runnable?

      topic = topic_timer.topic
      if topic.blank?
        topic_timer.destroy!
        return
      end

      if Guardian.new(topic_timer.user).can_delete?(topic)
        first_post = topic.ordered_posts.first
        PostDestroyer.new(topic_timer.user, first_post, context: I18n.t("topic_statuses.auto_deleted_by_timer")).destroy
        topic_timer.trash!(Discourse.system_user)
      end
    end

  end
end
