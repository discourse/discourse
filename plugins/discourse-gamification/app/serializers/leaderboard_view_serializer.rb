# frozen_string_literal: true

class LeaderboardViewSerializer < ApplicationSerializer
  attributes :personal

  has_one :leaderboard, serializer: LeaderboardSerializer, embed: :objects
  has_many :users, serializer: UserScoreSerializer, embed: :objects

  def leaderboard
    object[:leaderboard]
  end

  def users
    DiscourseGamification::GamificationLeaderboard.scores_for(
      object[:leaderboard].id,
      page: object[:page],
      period: object[:period],
      user_limit: object[:user_limit],
    )
  end

  def personal
    return {} if object[:for_user_id].blank?

    user_score =
      DiscourseGamification::GamificationLeaderboard.scores_for(
        object[:leaderboard].id,
        for_user_id: object[:for_user_id],
        period: object[:period],
      ).take

    { user: UserScoreSerializer.new(user_score, root: false), position: user_score.try(:position) }
  end
end
