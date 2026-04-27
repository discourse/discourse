# frozen_string_literal: true

class DiscourseGamification::AdminGamificationLeaderboardController < Admin::AdminController
  requires_plugin DiscourseGamification::PLUGIN_NAME

  def index
    render_serialized(
      { leaderboards: DiscourseGamification::GamificationLeaderboard.order(updated_at: :desc) },
      AdminGamificationIndexSerializer,
      root: false,
    )
  end

  def show
    leaderboard = DiscourseGamification::GamificationLeaderboard.find(params[:id])

    render_json_dump(
      { leaderboard: serialize_data(leaderboard, AdminLeaderboardSerializer, root: false) },
    )
  end

  def create
    params.require(%i[name created_by_id])

    leaderboard =
      DiscourseGamification::GamificationLeaderboard.new(
        name: params[:name],
        created_by_id: params[:created_by_id],
      )
    if leaderboard.save
      Jobs.enqueue(Jobs::RecalculateLeaderboardScores, leaderboard_id: leaderboard.id)

      render_serialized(leaderboard, AdminLeaderboardSerializer, root: false)
    else
      render_json_error(leaderboard)
    end
  end

  def update
    params.require(%i[id name])

    leaderboard = DiscourseGamification::GamificationLeaderboard.find(params[:id])
    raise Discourse::NotFound unless leaderboard

    previous_score_overrides = leaderboard.score_overrides
    previous_scorable_category_ids = leaderboard.scorable_category_ids

    leaderboard.update(
      name: params[:name],
      to_date: params[:to_date],
      from_date: params[:from_date],
      included_groups_ids: params[:included_groups_ids] || [],
      excluded_groups_ids: params[:excluded_groups_ids] || [],
      visible_to_groups_ids: params[:visible_to_groups_ids] || [],
      default_period: params[:default_period],
      period_filter_disabled: params[:period_filter_disabled] || false,
      score_overrides: (params[:score_overrides].presence&.to_unsafe_h&.transform_values(&:to_i)),
      scorable_category_ids: params[:scorable_category_ids].presence,
    )

    if leaderboard.save
      scoring_changed =
        leaderboard.score_overrides != previous_score_overrides ||
          leaderboard.scorable_category_ids != previous_scorable_category_ids

      if scoring_changed
        Jobs.enqueue(Jobs::RecalculateLeaderboardScores, leaderboard_id: leaderboard.id)
      else
        Jobs.enqueue(Jobs::RefreshLeaderboardPositions, leaderboard_id: leaderboard.id)
      end

      render json: success_json
    else
      render_json_error(leaderboard)
    end
  end

  def destroy
    params.require(:id)

    leaderboard = DiscourseGamification::GamificationLeaderboard.find(params[:id])

    if leaderboard && leaderboard.destroy
      Jobs.enqueue(Jobs::DeleteLeaderboardPositions, leaderboard_id: leaderboard.id)
    end

    render json: success_json
  end

  def recalculate_scores
    DiscourseGamification::RecalculateScoresRateLimiter.perform!

    since =
      begin
        Date.parse(params[:from_date]).midnight
      rescue StandardError
        raise Discourse::InvalidParameters.new(:from_date)
      end

    raise Discourse::InvalidParameters.new(:from_date) if since > Time.now

    Jobs.enqueue(Jobs::RecalculateScores, since: since, user_id: current_user.id)

    render json: success_json
  end
end
