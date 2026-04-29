# frozen_string_literal: true

module Jobs
  module DiscourseTopicVoting
    # Restores archived votes and refreshes the topic vote count when voting
    # should apply again (e.g. topic reopened/unarchived/recovered, or moved
    # into a voting category).
    class VoteReclaim < ::Jobs::Base
      def execute(args)
        topic = Topic.with_deleted.find_by(id: args[:topic_id])
        return if !topic

        ActiveRecord::Base.transaction do
          ::DiscourseTopicVoting::Vote.where(topic_id: topic.id).update_all(archive: false)
          topic.update_vote_count
        end

        Jobs.enqueue(Jobs::DiscourseTopicVoting::BackfillBadges, topic_id: topic.id)
      end
    end
  end
end
