# frozen_string_literal: true

module Jobs
  class DeleteTopic < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      if Guardian.new(topic_timer.user).can_delete?(topic)
        first_post = topic.ordered_posts.first

        PostDestroyer.new(
          topic_timer.user,
          first_post,
          context: I18n.t("topic_statuses.auto_deleted_by_timer"),
        ).destroy

        topic_timer.trash!(Discourse.system_user)
      end
    end
  end
end
