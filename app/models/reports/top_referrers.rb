# frozen_string_literal: true

Report.add_report("top_referrers") do |report|
  report.modes = [:table]

  report.labels = [
    {
      type: :user,
      properties: {
        username: :username,
        id: :user_id,
        avatar: :user_avatar_template,
      },
      title: I18n.t("reports.top_referrers.labels.user")
    },
    {
      property: :num_clicks,
      type: :number,
      title: I18n.t("reports.top_referrers.labels.num_clicks")
    },
    {
      property: :num_topics,
      type: :number,
      title: I18n.t("reports.top_referrers.labels.num_topics")
    }
  ]

  options = {
    end_date: report.end_date,
    start_date: report.start_date,
    limit: report.limit || 8
  }

  result = IncomingLinksReport.find(:top_referrers, options)
  report.data = result.data
end
