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
#  topic_id   :integer
#  user_id    :integer
#  archive    :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  topic_voting_votes_user_id_topic_id_idx  (user_id,topic_id) UNIQUE
#
