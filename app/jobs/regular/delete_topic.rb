module Jobs
  class DeleteTopic < Jobs::Base

    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])

      topic = topic_status_update&.topic

      if topic_status_update.blank? || topic.blank? ||
          topic_status_update.execute_at > Time.zone.now
        return
      end

      if Guardian.new(topic_status_update.user).can_delete?(topic)
        first_post = topic.ordered_posts.first
        PostDestroyer.new(topic_status_update.user, first_post, { context: I18n.t("topic_statuses.auto_deleted_by_timer") }).destroy
      end
    end

  end
end