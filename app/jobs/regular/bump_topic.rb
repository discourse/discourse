# frozen_string_literal: true

module Jobs
  class BumpTopic < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      guardian = topic_timer.user&.guardian

      unless guardian&.can_create_post_on_topic?(topic) || guardian&.can_set_topic_timer?(topic)
        topic_timer.trash!(Discourse.system_user)
        return
      end

      post = topic.add_small_action(Discourse.system_user, "autobumped", nil, bump: true)
      topic_timer.finish!(post ? :completed : :cancelled)
    end
  end
end
