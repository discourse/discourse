# frozen_string_literal: true

module ::DiscourseGamification
  class GamificationLeaderboardController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def respond
      discourse_expires_in 1.minute

      default_leaderboard_id = GamificationLeaderboard.first.id
      params[:id] ||= default_leaderboard_id
      leaderboard = GamificationLeaderboard.find(params[:id])

      period_param = params[:period] == "all" ? "all_time" : params[:period]

      raise Discourse::NotFound unless @guardian.can_see_leaderboard?(leaderboard)

      render_serialized(
        {
          leaderboard: leaderboard,
          page: params[:page].to_i,
          for_user_id: current_user&.id,
          period: leaderboard.resolve_period(period_param),
          user_limit: params[:user_limit]&.to_i,
        },
        LeaderboardViewSerializer,
        root: false,
      )
    rescue LeaderboardCachedView::NotReadyError => e
      Jobs.enqueue(Jobs::GenerateLeaderboardPositions, leaderboard_id: leaderboard.id)

      render json:
               LeaderboardSerializer
                 .new(leaderboard)
                 .as_json
                 .merge({ users: [], reason: e.message }),
             status: 202
    end
  end
end
