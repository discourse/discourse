# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EmotionDashboardReport
      def self.register!(plugin)
        Emotions::LIST.each do |emotion|
          plugin.add_report("emotion_#{emotion}", exclude_from_dashboard: true) do |report|
            query_results = DiscourseAi::Sentiment::EmotionDashboardReport.fetch_data(report)
            report.data = query_results.map { |row| { x: row.day, y: row.send(emotion) } }
            if report.facets.include?(:prev_period) && query_results.length > 30
              report.prev30Days = query_results[31..60].sum { |row| row.send(emotion) }
            end
          end
        end

        def self.fetch_data(report)
          model_name = DiscourseAi::Sentiment::PostClassification.active_model_name_for(:emotion)

          DB.query(<<~SQL, end: report.end_date, start: report.start_date, model_name: model_name)
            SELECT
              posts.created_at::DATE AS day,
              #{
              DiscourseAi::Sentiment::Emotions::LIST
                .map do |emotion|
                  "COUNT(*) FILTER (WHERE (classification_results.classification::jsonb->'#{emotion}')::float > 0.1) AS #{emotion}"
                end
                .join(",\n  ")
            }
            FROM
                classification_results
            INNER JOIN
                posts ON posts.id = classification_results.target_id AND
                posts.deleted_at IS NULL AND
                posts.created_at BETWEEN :start AND :end
            INNER JOIN
                topics ON topics.id = posts.topic_id AND
                topics.archetype = 'regular' AND
                topics.deleted_at IS NULL
            WHERE
                classification_results.target_type = 'Post' AND
                classification_results.model_used = :model_name
            GROUP BY 1
            ORDER BY 1 ASC
          SQL
        end
      end
    end
  end
end
