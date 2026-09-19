# frozen_string_literal: true

module DiscourseSolved
  class TopicAnswer < ActiveRecord::Base
    self.table_name = "discourse_solved_topic_answers"

    belongs_to :solved_topic, class_name: "DiscourseSolved::SolvedTopic"
    belongs_to :post, -> { with_deleted }, foreign_key: "answer_post_id"
    belongs_to :accepter, class_name: "User", foreign_key: "accepter_user_id"

    validates :solved_topic_id, presence: true
    validates :answer_post_id, presence: true, uniqueness: true
    validates :accepter_user_id, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_solved_topic_answers
#
#  id               :bigint           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  accepter_user_id :bigint           not null
#  answer_post_id   :bigint           not null
#  solved_topic_id  :bigint           not null
#
# Indexes
#
#  index_discourse_solved_topic_answers_on_answer_post_id   (answer_post_id) UNIQUE
#  index_discourse_solved_topic_answers_on_solved_topic_id  (solved_topic_id)
#
