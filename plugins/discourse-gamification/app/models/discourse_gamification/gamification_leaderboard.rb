# frozen_string_literal: true

module DiscourseGamification
  class GamificationLeaderboard < ::ActiveRecord::Base
    PAGE_SIZE = 100

    self.table_name = "gamification_leaderboards"

    has_many :leaderboard_scores,
             class_name: "DiscourseGamification::GamificationLeaderboardScore",
             foreign_key: :leaderboard_id,
             dependent: :delete_all

    validates :name, exclusion: { in: %w[new], message: "%{value} is reserved." }
    validate :validate_score_overrides

    attribute :period, :integer
    enum :period, { all_time: 0, yearly: 1, quarterly: 2, monthly: 3, weekly: 4, daily: 5 }

    VALID_SCORABLE_KEYS =
      Set.new(
        %w[
          like_given
          like_received
          solution
          user_invited
          time_read
          post_read
          topic_created
          post_created
          flag_created
          day_visited
          reaction_received
          reaction_given
          chat_reaction_received
          chat_reaction_given
          chat_message_created
        ],
      ).freeze

    def score_override_for(key)
      score_overrides&.dig(key)
    end

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

    private

    def validate_score_overrides
      return if score_overrides.blank?

      score_overrides.each do |key, value|
        if VALID_SCORABLE_KEYS.exclude?(key)
          errors.add(:score_overrides, "contains invalid scorable key: #{key}")
        end
        unless value.is_a?(Integer) && value >= 0
          errors.add(:score_overrides, "values must be non-negative integers")
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: gamification_leaderboards
#
#  id                     :bigint           not null, primary key
#  default_period         :integer          default(0)
#  excluded_groups_ids    :integer          default([]), not null, is an Array
#  from_date              :date
#  included_groups_ids    :integer          default([]), not null, is an Array
#  name                   :string           not null
#  period_filter_disabled :boolean          default(FALSE), not null
#  scorable_category_ids  :integer          is an Array
#  score_overrides        :jsonb
#  to_date                :date
#  visible_to_groups_ids  :integer          default([]), not null, is an Array
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  created_by_id          :integer          not null
#  for_category_id        :integer
#
# Indexes
#
#  index_gamification_leaderboards_on_name  (name) UNIQUE
#
