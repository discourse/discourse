# frozen_string_literal: true

Report.add_report("user_flagging_ratio") do |report|
  report.data = []

  report.modes = [:table]

  report.dates_filtering = true

  report.labels = [
    {
      type: :user,
      properties: {
        username: :username,
        id: :user_id,
        avatar: :avatar_template,
      },
      title: I18n.t("reports.user_flagging_ratio.labels.user")
    },
    {
      type: :number,
      property: :disagreed_flags,
      title: I18n.t("reports.user_flagging_ratio.labels.disagreed_flags")
    },
    {
      type: :number,
      property: :agreed_flags,
      title: I18n.t("reports.user_flagging_ratio.labels.agreed_flags")
    },
    {
      type: :number,
      property: :ignored_flags,
      title: I18n.t("reports.user_flagging_ratio.labels.ignored_flags")
    },
    {
      type: :number,
      property: :score,
      title: I18n.t("reports.user_flagging_ratio.labels.score")
    },
  ]

  statuses = ReviewableScore.statuses

  agreed = "SUM(CASE WHEN rs.status = #{statuses[:agreed]} THEN 1 ELSE 0 END)::numeric"
  disagreed = "SUM(CASE WHEN rs.status = #{statuses[:disagreed]} THEN 1 ELSE 0 END)::numeric"
  ignored = "SUM(CASE WHEN rs.status = #{statuses[:ignored]} THEN 1 ELSE 0 END)::numeric"

  sql = <<~SQL
    SELECT u.id,
           u.username,
           u.uploaded_avatar_id as avatar_id,
           CASE WHEN u.silenced_till IS NOT NULL THEN 't' ELSE 'f' END as silenced,
           #{disagreed} AS disagreed_flags,
           #{agreed} AS agreed_flags,
           #{ignored} AS ignored_flags,
           (
            CASE #{disagreed} WHEN 0 THEN #{agreed} * #{agreed}
            ELSE ROUND((1-(#{agreed} / #{disagreed})) * (#{disagreed} - #{agreed})) END
           ) AS score
    FROM users AS u
    INNER JOIN reviewable_scores AS rs ON rs.user_id = u.id
    WHERE u.id > 0
      AND rs.created_at >= :start_date
      AND rs.created_at <= :end_date
    GROUP BY u.id,
      u.username,
      u.uploaded_avatar_id,
      u.silenced_till
    ORDER BY score DESC
    LIMIT 100
    SQL

  DB.query(sql, start_date: report.start_date, end_date: report.end_date).each do |row|
    flagger = {}
    flagger[:user_id] = row.id
    flagger[:username] = row.username
    flagger[:avatar_template] = User.avatar_template(row.username, row.avatar_id)
    flagger[:disagreed_flags] = row.disagreed_flags
    flagger[:ignored_flags] = row.ignored_flags
    flagger[:agreed_flags] = row.agreed_flags
    flagger[:score] = row.score

    report.data << flagger
  end
end
