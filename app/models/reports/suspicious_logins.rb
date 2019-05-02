# frozen_string_literal: true

Report.add_report("suspicious_logins") do |report|
  report.modes = [:table]

  report.labels = [
    {
      type: :user,
      properties: {
        username: :username,
        id: :user_id,
        avatar: :avatar_template,
      },
      title: I18n.t("reports.suspicious_logins.labels.user")
    },
    {
      property: :client_ip,
      title: I18n.t("reports.suspicious_logins.labels.client_ip")
    },
    {
      property: :location,
      title: I18n.t("reports.suspicious_logins.labels.location")
    },
    {
      property: :browser,
      title: I18n.t("reports.suspicious_logins.labels.browser")
    },
    {
      property: :device,
      title: I18n.t("reports.suspicious_logins.labels.device")
    },
    {
      property: :os,
      title: I18n.t("reports.suspicious_logins.labels.os")
    },
    {
      type: :date,
      property: :login_time,
      title: I18n.t("reports.suspicious_logins.labels.login_time")
    },
  ]

  report.data = []

  sql = <<~SQL
    SELECT u.id user_id, u.username, u.uploaded_avatar_id, t.client_ip, t.user_agent, t.created_at login_time
    FROM user_auth_token_logs t
    JOIN users u ON u.id = t.user_id
    WHERE t.action = 'suspicious'
      AND t.created_at >= :start_date
      AND t.created_at <= :end_date
    ORDER BY t.created_at DESC
  SQL

  DB.query(sql, start_date: report.start_date, end_date: report.end_date).each do |row|
    data = {}

    ipinfo = DiscourseIpInfo.get(row.client_ip)
    browser = BrowserDetection.browser(row.user_agent)
    device = BrowserDetection.device(row.user_agent)
    os = BrowserDetection.os(row.user_agent)

    data[:username] = row.username
    data[:user_id] = row.user_id
    data[:avatar_template] = User.avatar_template(row.username, row.uploaded_avatar_id)
    data[:client_ip] = row.client_ip.to_s
    data[:location] = ipinfo[:location]
    data[:browser] = I18n.t("user_auth_tokens.browser.#{browser}")
    data[:device] = I18n.t("user_auth_tokens.device.#{device}")
    data[:os] = I18n.t("user_auth_tokens.os.#{os}")
    data[:login_time] = row.login_time

    report.data << data
  end
end
