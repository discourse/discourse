# frozen_string_literal: true

Report.add_report('web_crawlers') do |report|
  report.labels = [
    {
      type: :string,
      property: :user_agent,
      title: I18n.t('reports.web_crawlers.labels.user_agent')
    },
    {
      property: :count,
      type: :number,
      title: I18n.t('reports.web_crawlers.labels.page_views')
    }
  ]

  report.modes = [:table]

  report.data = WebCrawlerRequest.where('date >= ? and date <= ?', report.start_date, report.end_date)
    .limit(200)
    .order('sum_count DESC')
    .group(:user_agent).sum(:count)
    .map { |ua, count| { user_agent: ua, count: count } }
end
