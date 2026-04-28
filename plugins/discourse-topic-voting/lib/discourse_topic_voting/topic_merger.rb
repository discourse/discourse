# frozen_string_literal: true

module DiscourseTopicVoting
  class TopicMerger
    def self.merge(source_topic, target_topic)
      new(source_topic, target_topic).merge
    end

    def initialize(source_topic, target_topic)
      @source_topic = source_topic
      @target_topic = target_topic
    end

    def merge
      moved_votes = 0
      duplicated_votes = 0

      who_voted = @source_topic.votes.map(&:user)
      if who_voted.present? && @source_topic.closed
        who_voted.each do |user|
          next if user.blank?

          user_votes = user.topics_with_vote.pluck(:topic_id)
          user_archived_votes = user.topics_with_archived_vote.pluck(:topic_id)

          if user_votes.include?(@source_topic.id) || user_archived_votes.include?(@source_topic.id)
            if user_votes.include?(@target_topic.id) ||
                 user_archived_votes.include?(@target_topic.id)
              duplicated_votes += 1
              user.votes.destroy_by(topic_id: @source_topic.id)
            else
              user
                .votes
                .find_by(topic_id: @source_topic.id, user_id: user.id)
                .update!(topic_id: @target_topic.id, archive: @target_topic.closed)
              moved_votes += 1
            end
          else
            next
          end
        end
      end

      if moved_votes > 0
        @source_topic.update_vote_count
        @target_topic.update_vote_count

        Jobs.enqueue(Jobs::DiscourseTopicVoting::BackfillBadges, topic_id: @target_topic.id)

        if moderator_post = @source_topic.ordered_posts.where(action_code: "split_topic").last
          moderator_post.raw << "\n\n#{I18n.t("topic_voting.votes_moved", count: moved_votes)}"
          if duplicated_votes > 0
            moderator_post.raw << " #{I18n.t("topic_voting.duplicated_votes", count: duplicated_votes)}"
          end
          moderator_post.save!
        end
      end
    end
  end
end
