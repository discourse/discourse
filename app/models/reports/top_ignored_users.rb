# frozen_string_literal: true

Report.add_report("top_ignored_users") do |report|
  report.modes = [:table]

  report.labels = [
    {
      type: :user,
      properties: {
        id: :ignored_user_id,
        username: :ignored_username,
        avatar: :ignored_user_avatar_template,
      },
      title: I18n.t("reports.top_ignored_users.labels.ignored_user")
    },
    {
      type: :number,
      properties: [
        :ignores_count,
      ],
      title: I18n.t("reports.top_ignored_users.labels.ignores_count")
    },
    {
      type: :number,
      properties: [
        :mutes_count,
      ],
      title: I18n.t("reports.top_ignored_users.labels.mutes_count")
    }
  ]

  report.data = []

  sql = <<~SQL
      WITH ignored_users AS (
        SELECT
        ignored_user_id as user_id,
        COUNT(*) AS ignores_count
        FROM ignored_users
        WHERE created_at >= '#{report.start_date}' AND created_at <= '#{report.end_date}'
        GROUP BY ignored_user_id
        ORDER BY COUNT(*) DESC
        LIMIT :limit
      ),
      muted_users AS (
        SELECT
        muted_user_id as user_id,
        COUNT(*) AS mutes_count
        FROM muted_users
        WHERE created_at >= '#{report.start_date}' AND created_at <= '#{report.end_date}'
        GROUP BY muted_user_id
        ORDER BY COUNT(*) DESC
        LIMIT :limit
      )

      SELECT u.id as user_id,
             u.username as username,
             u.uploaded_avatar_id as uploaded_avatar_id,
             ig.ignores_count as ignores_count,
             COALESCE(mu.mutes_count, 0) as mutes_count,
             ig.ignores_count + COALESCE(mu.mutes_count, 0) as total
      FROM users as u
      JOIN ignored_users as ig ON ig.user_id = u.id
      LEFT OUTER JOIN muted_users as mu ON mu.user_id = u.id
      ORDER BY total DESC
  SQL

  DB.query(sql, limit: report.limit || 250).each do |row|
    report.data << {
      ignored_user_id: row.user_id,
      ignored_username: row.username,
      ignored_user_avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
      ignores_count: row.ignores_count,
      mutes_count: row.mutes_count,
    }
  end
end
