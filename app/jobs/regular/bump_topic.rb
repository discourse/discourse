# frozen_string_literal: true

module Jobs
  class BumpTopic < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      guardian = Guardian.new(topic_timer.user)

      if guardian.can_create_post_on_topic?(topic) || guardian.can_set_topic_timer?(topic)
        topic.add_small_action(Discourse.system_user, "autobumped", nil, bump: true)
      end

      topic_timer.trash!(Discourse.system_user)
    end
  end
end
