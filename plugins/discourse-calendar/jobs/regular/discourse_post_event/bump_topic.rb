# frozen_string_literal: true

module Jobs
  class DiscoursePostEventBumpTopic < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless topic = Topic.find_by(id: args[:topic_id].to_i)
      return unless by_user = User.find_by(id: topic.user_id)
      return if args[:date].blank?

      date = args[:date]

      begin
        date = Time.parse(date) if date.is_a?(String)
      rescue ArgumentError
        return
      end

      return if date <= Time.now.utc

      topic.set_or_create_timer(TopicTimer.types[:bump], args[:date], by_user:)
    end
  end
end
