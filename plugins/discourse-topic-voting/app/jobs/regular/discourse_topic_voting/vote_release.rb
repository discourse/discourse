# frozen_string_literal: true

module Jobs
  module DiscourseTopicVoting
    class VoteRelease < ::Jobs::Base
      def execute(args)
        if topic = Topic.with_deleted.find_by(id: args[:topic_id])
          votes = ::DiscourseTopicVoting::Vote.where(topic_id: args[:topic_id])
          votes.update_all(archive: true)

          topic.update_vote_count

          return if args[:trashed]

          votes.find_each do |vote|
            Notification.create!(
              user_id: vote.user_id,
              notification_type: Notification.types[:votes_released],
              topic_id: vote.topic_id,
              data: { message: "votes_released", title: "votes_released" }.to_json,
            )
          rescue StandardError
            # If one notification crashes, inform others
          end
        end
      end
    end
  end
end
