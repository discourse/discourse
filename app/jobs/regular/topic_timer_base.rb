# frozen_string_literal: true

module Jobs
  class TopicTimerBase < ::Jobs::Base
    def execute(args)
      @args = args

      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])
      return if !topic_timer&.runnable?

      topic = topic_timer.topic
      if topic.blank?
        topic_timer.destroy!
        return
      end

      execute_timer_action(topic_timer, topic)
    end
  end
end
