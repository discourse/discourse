# frozen_string_literal: true

module Jobs
  module DiscourseTopicVoting
    class VoteReclaim < ::Jobs::Base
      def execute(args)
        if topic = Topic.with_deleted.find_by(id: args[:topic_id])
          ActiveRecord::Base.transaction do
            ::DiscourseTopicVoting::Vote.where(topic_id: args[:topic_id]).update_all(archive: false)
            topic.update_vote_count
          end
        end
      end
    end
  end
end
