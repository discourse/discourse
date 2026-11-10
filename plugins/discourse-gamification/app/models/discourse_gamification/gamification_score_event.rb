# frozen_string_literal: true

module DiscourseGamification
  class GamificationScoreEvent < ::ActiveRecord::Base
    self.table_name = "gamification_score_events"

    belongs_to :user
    belongs_to :category, optional: true

    validates :category,
              presence: {
                message: :required,
              },
              if: -> { !category_id.nil? && will_save_change_to_category_id? }
  end
end

# == Schema Information
#
# Table name: gamification_score_events
#
#  id          :bigint           not null, primary key
#  date        :date             not null
#  description :text
#  points      :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  category_id :integer
#  user_id     :integer          not null
#
# Indexes
#
#  index_gamification_score_events_on_date              (date)
#  index_gamification_score_events_on_user_id_and_date  (user_id,date)
#
