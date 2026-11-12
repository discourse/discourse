# frozen_string_literal: true

module Jobs
  module DiscourseTopicVoting
    # Archives votes and refreshes the topic vote count when voting no longer
    # applies (topic closed/archived/trashed, or moved out of a voting
    # category). Notifies voters unless trashed.
    class VoteRelease < ::Jobs::Base
      def execute(args)
        topic = Topic.with_deleted.find_by(id: args[:topic_id])
        return if topic.blank?

        votes = ::DiscourseTopicVoting::Vote.where(topic_id: topic.id)
        votes.update_all(archive: true)

        topic.update_vote_count

        # The user can't reach a trashed topic from the notification,
        # so no need to send one.
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
