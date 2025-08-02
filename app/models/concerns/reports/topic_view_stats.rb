# frozen_string_literal: true

module Reports::TopicViewStats
  extend ActiveSupport::Concern

  class_methods do
    def report_topic_view_stats(report)
      report.modes = [Report::MODES[:table]]

      category_id, include_subcategories = report.add_category_filter

      category_ids = include_subcategories ? Category.subcategory_ids(category_id) : [category_id]
      sql = <<~SQL
        SELECT
          topic_view_stats.topic_id,
          topics.title AS topic_title,
          SUM(topic_view_stats.anonymous_views) AS total_anonymous_views,
          SUM(topic_view_stats.logged_in_views) AS total_logged_in_views,
          SUM(topic_view_stats.anonymous_views + topic_view_stats.logged_in_views) AS total_views
        FROM topic_view_stats
        INNER JOIN topics ON topics.id = topic_view_stats.topic_id
        WHERE viewed_at BETWEEN :start_date AND :end_date
        #{category_ids.any? ? "AND topics.category_id IN (:category_ids)" : ""}
        GROUP BY topic_view_stats.topic_id, topics.title
        ORDER BY total_views DESC
        LIMIT 100
      SQL

      data =
        DB.query(
          sql,
          start_date: report.start_date,
          end_date: report.end_date,
          category_ids: category_ids,
        )

      report.labels = [
        {
          type: :topic,
          properties: {
            title: :topic_title,
            id: :topic_id,
          },
          title: I18n.t("reports.topic_view_stats.labels.topic"),
        },
        {
          property: :total_anonymous_views,
          type: :number,
          title: I18n.t("reports.topic_view_stats.labels.anon_views"),
        },
        {
          property: :total_logged_in_views,
          type: :number,
          title: I18n.t("reports.topic_view_stats.labels.logged_in_views"),
        },
        {
          property: :total_views,
          type: :number,
          title: I18n.t("reports.topic_view_stats.labels.total_views"),
        },
      ]

      report.data =
        data.map do |row|
          {
            topic_id: row.topic_id,
            topic_title: row.topic_title,
            total_anonymous_views: row.total_anonymous_views,
            total_logged_in_views: row.total_logged_in_views,
            total_views: row.total_views,
          }
        end
    end
  end
end
