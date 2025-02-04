# frozen_string_literal: true

module Reports::TopUsersByLikesReceivedFromInferiorTrustLevel
  extend ActiveSupport::Concern

  class_methods do
    def report_top_users_by_likes_received_from_inferior_trust_level(report)
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
          title:
            I18n.t("reports.top_users_by_likes_received_from_inferior_trust_level.labels.user"),
        },
        {
          type: :number,
          property: :trust_level,
          title:
            I18n.t(
              "reports.top_users_by_likes_received_from_inferior_trust_level.labels.trust_level",
            ),
        },
        {
          type: :number,
          property: :qtt_like,
          title:
            I18n.t("reports.top_users_by_likes_received_from_inferior_trust_level.labels.qtt_like"),
        },
      ]

      sql = <<~SQL
      WITH user_liked_tl_lower AS (
        SELECT
            users.id user_id,
            users.username as username,
            users.uploaded_avatar_id as uploaded_avatar_id,
            users.trust_level,
            COUNT(*) qtt_like,
            rank() OVER (PARTITION BY users.trust_level ORDER BY COUNT(*) DESC)
        FROM users
        INNER JOIN posts p ON p.user_id = users.id
        INNER JOIN user_actions ua ON ua.target_post_id = p.id AND ua.action_type = 1
        INNER JOIN users u_liked ON ua.user_id = u_liked.id AND u_liked.trust_level < users.trust_level
        WHERE ua.created_at::date BETWEEN :start_date AND :end_date
        GROUP BY users.id
        ORDER BY trust_level DESC, qtt_like DESC
      )

      SELECT * FROM user_liked_tl_lower
      WHERE rank <= 10
      SQL

      DB
        .query(sql, start_date: report.start_date, end_date: report.end_date)
        .each do |row|
          report.data << {
            user_id: row.user_id,
            username: row.username,
            user_avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
            trust_level: row.trust_level,
            qtt_like: row.qtt_like,
          }
        end
    end
  end
end
