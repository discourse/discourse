# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBumpTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless topic = Topic.find_by(id: args[:topic_id].to_i)
      return if args[:date].blank?

      event_user = User.find_by(id: topic.user_id)
      timer = TopicTimer.find_by(topic_id: args[:topic_id].to_i)

      topic.set_or_create_timer(TopicTimer.types[:bump], args[:date], by_user: event_user)
    end
  end
end
