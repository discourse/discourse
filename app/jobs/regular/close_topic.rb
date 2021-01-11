# frozen_string_literal: true

module Jobs
  class CloseTopic < ::Jobs::Base
    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])
      return if !topic_timer&.runnable?

      topic = topic_timer.topic
      user = topic_timer.user
      silent = args[:silent]

      if topic.blank? || topic.closed?
        topic_timer.destroy!
        return
      end

      if !Guardian.new(user).can_close_topic?(topic)
        topic_timer.destroy!
        topic.reload

        if topic_timer.based_on_last_post
          topic.inherit_auto_close_from_category(timer_type: silent ? :silent_close : :close)
        end

        return
      end

      # this handles deleting the topic timer as wel, see TopicStatusUpdater
      topic.update_status('autoclosed', true, user, { silent: silent })
    end
  end
end
