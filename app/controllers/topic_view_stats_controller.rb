# frozen_string_literal: true

class TopicViewStatsController < ApplicationController
  MAX_STATS_PER_API_REQUEST = 300

  def index
    topic = Topic.find(params[:topic_id].to_i)
    guardian.ensure_can_see!(topic)

    from = 30.days.ago.to_date
    to = Date.today

    begin
      from = params[:from].to_date if params[:from].present?
      to = params[:to].to_date if params[:to].present?
    rescue Date::Error
      render_json_error(I18n.t("topic_view_stats.invalid_date"), status: 422)
      return
    end

    stats =
      TopicViewStat
        .where(topic_id: topic.id, viewed_at: from..to)
        .order(viewed_at: :desc)
        .limit(MAX_STATS_PER_API_REQUEST)

    rows = []

    stats.each do |stat|
      rows << { viewed_at: stat.viewed_at, views: stat.anonymous_views + stat.logged_in_views }
    end

    render json: { topic_id: topic.id, stats: rows.reverse }
  end
end
