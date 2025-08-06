# frozen_string_literal: true

class AdminGamificationIndexSerializer < ApplicationSerializer
  attribute :gamification_recalculate_scores_remaining
  has_many :gamification_leaderboards, serializer: LeaderboardSerializer, embed: :objects
  has_many :gamification_groups, serializer: BasicGroupSerializer, embed: :object

  def gamification_leaderboards
    object[:leaderboards]
  end

  def gamification_groups
    Group.all
  end

  def gamification_recalculate_scores_remaining
    DiscourseGamification::RecalculateScoresRateLimiter.remaining
  end
end
