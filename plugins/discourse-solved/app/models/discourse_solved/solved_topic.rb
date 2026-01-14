# frozen_string_literal: true

module DiscourseSolved
  class SolvedTopic < ActiveRecord::Base
    self.table_name = "discourse_solved_solved_topics"

    belongs_to :topic, class_name: "Topic"
    belongs_to :answer_post, class_name: "Post", foreign_key: "answer_post_id"
    belongs_to :accepter, class_name: "User", foreign_key: "accepter_user_id"
    belongs_to :topic_timer, dependent: :destroy

    validates :topic_id, presence: true
    validates :answer_post_id, presence: true
    validates :accepter_user_id, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_solved_solved_topics
#
#  id               :bigint           not null, primary key
#  topic_id         :integer          not null
#  answer_post_id   :integer          not null
#  accepter_user_id :integer          not null
#  topic_timer_id   :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_discourse_solved_solved_topics_on_answer_post_id  (answer_post_id) UNIQUE
#  index_discourse_solved_solved_topics_on_topic_id        (topic_id) UNIQUE
#
