# frozen_string_literal: true

module Jobs
  class ToggleTopicClosed < ::Jobs::Base
    def execute(args)
      Discourse.deprecate(
        "ToggleTopicClosed is deprecated. Use OpenTopic and CloseTopic instead.",
        drop_from: "3.3.0",
      )

      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])

      # state false is Open Topic
      # state true is Close Topic
      state = !!args[:state]
      timer_type = args[:silent] ? :silent_close : :close

      return if topic_timer.blank? || topic_timer.execute_at > Time.zone.now

      if (topic = topic_timer.topic).blank? || topic.closed == state
        topic_timer.destroy!
        return
      end

      user = topic_timer.user

      if Guardian.new(user).can_close_topic?(topic)
        if state == false && topic.auto_close_threshold_reached?
          topic.set_or_create_timer(
            TopicTimer.types[:open],
            SiteSetting.num_hours_to_close_topic,
            by_user: Discourse.system_user,
          )
        else
          topic.update_status("autoclosed", state, user, { silent: args[:silent] })
        end

        topic.inherit_auto_close_from_category(timer_type: timer_type) if state == false
      else
        topic_timer.destroy!
        topic.reload

        if topic_timer.based_on_last_post
          topic.inherit_auto_close_from_category(timer_type: timer_type)
        end
      end
    end
  end
end
