# frozen_string_literal: true

module DiscourseSolved
  class SharedIssue < ActiveRecord::Base
    self.table_name = "discourse_solved_shared_issues"

    belongs_to :user
    belongs_to :topic, -> { with_deleted }

    validates :topic_id, presence: true, uniqueness: { scope: :user_id }
    validates :user_id, presence: true

    def self.count_for(topic)
      where(topic: topic).count
    end
  end
end

# == Schema Information
#
# Table name: discourse_solved_shared_issues
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_discourse_solved_shared_issues_on_topic_id_and_user_id  (topic_id,user_id) UNIQUE
#  index_discourse_solved_shared_issues_on_user_id_and_topic_id  (user_id,topic_id)
#
