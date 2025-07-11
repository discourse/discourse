# frozen_string_literal: true

module DiscourseTopicVoting
  class TopicVoteCount < ActiveRecord::Base
    self.table_name = "topic_voting_topic_vote_count"

    belongs_to :topic
  end
end

# == Schema Information
#
# Table name: topic_voting_topic_vote_count
#
#  id          :bigint           not null, primary key
#  topic_id    :integer
#  votes_count :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_topic_voting_topic_vote_count_on_topic_id  (topic_id) UNIQUE
#  topic_voting_topic_vote_count_topic_id_idx       (topic_id) UNIQUE
#
