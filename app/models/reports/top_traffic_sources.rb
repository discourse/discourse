# frozen_string_literal: true

Report.add_report('top_traffic_sources') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.modes = [:table]

  report.labels = [
    {
      property: :domain,
      title: I18n.t('reports.top_traffic_sources.labels.domain')
    },
    {
      property: :num_clicks,
      type: :number,
      title: I18n.t('reports.top_traffic_sources.labels.num_clicks')
    },
    {
      property: :num_topics,
      type: :number,
      title: I18n.t('reports.top_traffic_sources.labels.num_topics')
    }
  ]

  options = {
    end_date: report.end_date,
    start_date: report.start_date,
    limit: report.limit || 8,
    category_id: category_filter
  }

  result = IncomingLinksReport.find(:top_traffic_sources, options)
  report.data = result.data
end
