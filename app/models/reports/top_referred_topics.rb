# frozen_string_literal: true

Report.add_report('top_referred_topics') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.modes = [:table]

  report.labels = [
    {
      type: :topic,
      properties: {
        title: :topic_title,
        id: :topic_id
      },
      title: I18n.t('reports.top_referred_topics.labels.topic')
    },
    {
      property: :num_clicks,
      type: :number,
      title: I18n.t('reports.top_referred_topics.labels.num_clicks')
    }
  ]

  options = {
    end_date: report.end_date,
    start_date: report.start_date,
    limit: report.limit || 8,
    category_id: category_filter
  }
  result = nil
  result = IncomingLinksReport.find(:top_referred_topics, options)
  report.data = result.data
end
