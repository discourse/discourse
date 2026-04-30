# frozen_string_literal: true

module DiscourseSolved
  class MeToo < ActiveRecord::Base
    self.table_name = "discourse_solved_me_toos"

    belongs_to :topic
    belongs_to :user

    validates :topic_id, presence: true, uniqueness: { scope: :user_id }
    validates :user_id, presence: true
  end
end

# == Schema Information
#
# Table name: discourse_solved_me_toos
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_discourse_solved_me_toos_on_topic_id              (topic_id)
#  index_discourse_solved_me_toos_on_topic_id_and_user_id  (topic_id,user_id) UNIQUE
#
