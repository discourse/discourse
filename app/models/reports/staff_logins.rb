# frozen_string_literal: true

Report.add_report("staff_logins") do |report|
  report.modes = [:table]

  report.data = []

  report.labels = [
    {
      type: :user,
      properties: {
        username: :username,
        id: :user_id,
        avatar: :avatar_template,
      },
      title: I18n.t("reports.staff_logins.labels.user")
    },
    {
      property: :location,
      title: I18n.t("reports.staff_logins.labels.location")
    },
    {
      property: :created_at,
      type: :precise_date,
      title: I18n.t("reports.staff_logins.labels.login_at")
    }
  ]

  sql = <<~SQL
    SELECT
      t1.created_at created_at,
      t1.client_ip client_ip,
      u.username username,
      u.uploaded_avatar_id uploaded_avatar_id,
      u.id user_id
    FROM (
      SELECT DISTINCT ON (t.client_ip, t.user_id) t.client_ip, t.user_id, t.created_at
      FROM user_auth_token_logs t
      WHERE t.user_id IN (#{User.admins.pluck(:id).join(',')})
        AND t.created_at >= :start_date
        AND t.created_at <= :end_date
      ORDER BY t.client_ip, t.user_id, t.created_at DESC
      LIMIT #{report.limit || 20}
    ) t1
    JOIN users u ON u.id = t1.user_id
    ORDER BY created_at DESC
  SQL

  DB.query(sql, start_date: report.start_date, end_date: report.end_date).each do |row|
    data = {}
    data[:avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
    data[:user_id] = row.user_id
    data[:username] = row.username
    data[:location] = DiscourseIpInfo.get(row.client_ip)[:location]
    data[:created_at] = row.created_at

    report.data << data
  end
end
