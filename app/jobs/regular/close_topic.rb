# frozen_string_literal: true

module Jobs
  class CloseTopic < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      silent = @args[:silent]
      user = topic_timer.user

      if topic.closed?
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

      # this handles deleting the topic timer as well, see TopicStatusUpdater
      topic.update_status('autoclosed', true, user, { silent: silent })

      MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
    end
  end
end
