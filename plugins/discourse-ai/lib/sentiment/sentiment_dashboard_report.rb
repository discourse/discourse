# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentDashboardReport
      include Constants

      def self.register!(plugin)
        plugin.add_report("overall_sentiment") do |report|
          report.modes = [:stacked_chart]
          threshold = SENTIMENT_THRESHOLD

          sentiment_count_sql = Proc.new { |sentiment| <<~SQL }
            COUNT(
              CASE WHEN (cr.classification::jsonb->'#{sentiment}')::float > :threshold THEN 1 ELSE NULL END
            )
          SQL

          grouped_sentiments =
            DB.query(
              <<~SQL,
            SELECT
              DATE_TRUNC('day', p.created_at)::DATE AS posted_at,
              #{sentiment_count_sql.call("positive")} - #{sentiment_count_sql.call("negative")} AS sentiment_count
            FROM
              classification_results AS cr
            INNER JOIN posts p ON p.id = cr.target_id AND cr.target_type = 'Post'
            INNER JOIN topics t ON t.id = p.topic_id
            INNER JOIN categories c ON c.id = t.category_id
            WHERE
              t.archetype = 'regular' AND
              p.user_id > 0 AND
              cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest' AND
              (p.created_at > :report_start AND p.created_at < :report_end)
            GROUP BY DATE_TRUNC('day', p.created_at)
            ORDER BY 1 ASC
          SQL
              report_start: report.start_date,
              report_end: report.end_date,
              threshold: threshold,
            )

          return report if grouped_sentiments.empty?

          report.data = [
            {
              req: "overall_sentiment",
              color: report.colors[:lime],
              label: I18n.t("discourse_ai.sentiment.reports.overall_sentiment"),
              data:
                grouped_sentiments.map do |gs|
                  { x: gs.posted_at, y: gs.public_send("sentiment_count") }
                end,
            },
          ]
        end
      end
    end
  end
end
