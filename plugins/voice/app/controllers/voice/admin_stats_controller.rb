# frozen_string_literal: true

module Voice
  class AdminStatsController < ::Admin::AdminController
    requires_plugin "voice"

    PERIOD_DAYS = { "daily" => 1, "weekly" => 7, "monthly" => 30, "quarterly" => 90 }.freeze
    DURATION_SQL = "EXTRACT(EPOCH FROM (COALESCE(left_at, NOW()) - joined_at))"

    def overview
      sessions = sessions_in_period

      total_sessions = sessions.count
      unique_users = sessions.distinct.count(:user_id)
      avg_duration = sessions.average(Arel.sql(DURATION_SQL)).to_f.round

      render json: { total_sessions:, unique_users:, avg_duration: }
    end

    def rooms
      rows =
        sessions_in_period
          .joins("LEFT JOIN voice_rooms ON voice_rooms.id = voice_sessions.room_id")
          .group(:room_id, "voice_rooms.name")
          .select(
            "voice_sessions.room_id",
            # NULL when the room was deleted; the dashboard renders a fallback.
            "voice_rooms.name AS room_name",
            "COUNT(DISTINCT voice_sessions.user_id) AS unique_users",
            "ROUND(SUM(#{DURATION_SQL})) AS total_seconds",
          )
          .order(Arel.sql("total_seconds DESC"))
          .limit(50)

      render json: {
               rooms:
                 rows.map do |r|
                   {
                     room_id: r.room_id,
                     room_name: r.room_name,
                     unique_users: r.unique_users,
                     total_seconds: r.total_seconds.to_i,
                   }
                 end,
             }
    end

    def users
      rows =
        sessions_in_period
          .group(:user_id)
          .select(
            "voice_sessions.user_id",
            "COUNT(*) AS session_count",
            "ROUND(SUM(#{DURATION_SQL})) AS total_seconds",
          )
          .order(Arel.sql("total_seconds DESC"))
          .limit(50)

      user_ids = rows.map(&:user_id)
      users_by_id = User.where(id: user_ids).index_by(&:id)

      render json: {
               users:
                 rows.map do |r|
                   user = users_by_id[r.user_id]
                   {
                     user_id: r.user_id,
                     username: user&.username,
                     name: user&.name,
                     avatar_template: user&.avatar_template,
                     session_count: r.session_count,
                     total_seconds: r.total_seconds.to_i,
                   }
                 end,
             }
    end

    private

    def sessions_in_period
      if params[:period] == "custom" && params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])

        Voice::Session.where(
          "joined_at >= ? AND joined_at <= ?",
          start_date.beginning_of_day,
          end_date.end_of_day,
        )
      else
        days = PERIOD_DAYS.fetch(params[:period].to_s, 7)
        Voice::Session.where("joined_at > ?", days.days.ago)
      end
    end
  end
end
