# frozen_string_literal: true

module DiscourseTopicVoting
  class Vote < ActiveRecord::Base
    self.table_name = "topic_voting_votes"

    belongs_to :user
    belongs_to :topic
  end
end

# == Schema Information
#
# Table name: topic_voting_votes
#
#  id         :bigint           not null, primary key
#  archive    :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer
#  user_id    :integer
#
# Indexes
#
#  index_topic_voting_votes_on_topic_id_and_created_at  (topic_id,created_at)
#  topic_voting_votes_user_id_topic_id_idx              (user_id,topic_id) UNIQUE
#
