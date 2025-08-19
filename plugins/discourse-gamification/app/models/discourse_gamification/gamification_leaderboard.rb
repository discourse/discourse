# frozen_string_literal: true

module ::DiscourseGamification
  class GamificationLeaderboard < ::ActiveRecord::Base
    PAGE_SIZE = 100

    self.table_name = "gamification_leaderboards"

    validates :name, exclusion: { in: %w[new], message: "%{value} is reserved." }

    attribute :period, :integer
    enum :period, { all_time: 0, yearly: 1, quarterly: 2, monthly: 3, weekly: 4, daily: 5 }

    def resolve_period(given_period)
      return given_period if self.class.periods.key?(given_period)

      self.class.periods.key(default_period) || "all_time"
    end

    def self.find_position_by(leaderboard_id:, for_user_id:, period: nil)
      self.scores_for(leaderboard_id, for_user_id: for_user_id, period: period).first
    end

    def self.scores_for(leaderboard_id, page: 0, for_user_id: false, period: nil, user_limit: nil)
      offset = PAGE_SIZE * page
      limit = user_limit || PAGE_SIZE
      period = period || "all_time"

      leaderboard = self.find(leaderboard_id)

      return [] unless leaderboard

      LeaderboardCachedView.new(leaderboard).scores(
        page: page,
        for_user_id: for_user_id,
        period: period,
        limit: limit,
        offset: offset,
      )
    end
  end
end

# == Schema Information
#
# Table name: gamification_leaderboards
#
#  id                     :bigint           not null, primary key
#  name                   :string           not null
#  from_date              :date
#  to_date                :date
#  for_category_id        :integer
#  created_by_id          :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  visible_to_groups_ids  :integer          default([]), not null, is an Array
#  included_groups_ids    :integer          default([]), not null, is an Array
#  excluded_groups_ids    :integer          default([]), not null, is an Array
#  default_period         :integer          default(0)
#  period_filter_disabled :boolean          default(FALSE), not null
#
# Indexes
#
#  index_gamification_leaderboards_on_name  (name) UNIQUE
#
