# frozen_string_literal: true

module Reports::TopUsersByLikesReceived
  extend ActiveSupport::Concern

  class_methods do
    def report_top_users_by_likes_received(report)
      report.icon = "heart"
      report.data = []

      report.modes = [Report::MODES[:table]]

      report.dates_filtering = true

      report.labels = [
        {
          type: :user,
          properties: {
            id: :user_id,
            username: :username,
            avatar: :user_avatar_template,
          },
          title: I18n.t("reports.top_users_by_likes_received.labels.user"),
        },
        {
          type: :number,
          property: :qtt_like,
          title: I18n.t("reports.top_users_by_likes_received.labels.qtt_like"),
        },
      ]

      sql = <<~SQL
      SELECT
        ua.user_id AS user_id,
        u.username as username,
        u.uploaded_avatar_id as uploaded_avatar_id,
        COUNT(*) qtt_like
      FROM user_actions ua
      INNER JOIN users u on ua.user_id = u.id
      WHERE ua.created_at::date BETWEEN :start_date AND :end_date
        AND ua.action_type = 2
      GROUP BY ua.user_id, u.username, u.uploaded_avatar_id
      ORDER BY qtt_like  DESC
      LIMIT 10
      SQL

      DB
        .query(sql, start_date: report.start_date, end_date: report.end_date)
        .each do |row|
          report.data << {
            user_id: row.user_id,
            username: row.username,
            user_avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
            qtt_like: row.qtt_like,
          }
        end
    end
  end
end
