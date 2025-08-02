# frozen_string_literal: true

module Jobs
  class OpenTopic < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      user = topic_timer.user

      if !Guardian.new(user).can_open_topic?(topic) || topic.open?
        topic_timer.destroy!
        topic.reload

        topic.inherit_auto_close_from_category(timer_type: :close)

        return
      end

      # guards against reopening a topic too early if the topic has
      # been auto closed because of reviewables/reports, this will
      # just update the existing topic timer and push it down the line
      if topic.auto_close_threshold_reached?
        topic.set_or_create_timer(
          TopicTimer.types[:open],
          SiteSetting.num_hours_to_close_topic,
          by_user: Discourse.system_user,
        )
      else
        # autoclosed, false is just another way of saying open.
        # this handles deleting the topic timer as well, see TopicStatusUpdater
        topic.update_status("autoclosed", false, user)
      end

      topic.inherit_auto_close_from_category(timer_type: :close)

      MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
    end
  end
end
