# frozen_string_literal: true

module ::DiscourseGamification
  class GamificationScoreEvent < ::ActiveRecord::Base
    self.table_name = "gamification_score_events"

    belongs_to :user
  end
end

# == Schema Information
#
# Table name: gamification_score_events
#
#  id          :bigint           not null, primary key
#  user_id     :integer          not null
#  date        :date             not null
#  points      :integer          not null
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_gamification_score_events_on_date              (date)
#  index_gamification_score_events_on_user_id_and_date  (user_id,date)
#
