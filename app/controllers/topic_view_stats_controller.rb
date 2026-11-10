# frozen_string_literal: true

class TopicViewStatsController < ApplicationController
  def index
    topic = Topic.find_by(id: params[:topic_id].to_i)
    raise Discourse::NotFound unless topic

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
      begin
        TopicViewStatsQuery.call(topic:, guardian:, from:, to:)
      rescue Discourse::InvalidAccess
        raise if SiteSetting.detailed_404

        raise Discourse::NotFound
      end

    rows = []

    stats.each do |stat|
      rows << { viewed_at: stat.viewed_at, views: stat.anonymous_views + stat.logged_in_views }
    end

    render json: { topic_id: topic.id, stats: rows }
  end
end
