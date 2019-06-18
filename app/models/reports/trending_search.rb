# frozen_string_literal: true

Report.add_report("trending_search") do |report|
  report.labels = [
    {
      property: :term,
      type: :text,
      title: I18n.t("reports.trending_search.labels.term")
    },
    {
      property: :searches,
      type: :number,
      title: I18n.t("reports.trending_search.labels.searches")
    },
    {
      type: :percent,
      property: :ctr,
      title: I18n.t("reports.trending_search.labels.click_through")
    }
  ]

  report.data = []

  report.modes = [:table]

  trends = SearchLog.trending_from(report.start_date,
    end_date: report.end_date,
    limit: report.limit
  )

  trends.each do |trend|
    report.data << {
      term: trend.term,
      searches: trend.searches,
      ctr: trend.ctr
    }
  end
end
