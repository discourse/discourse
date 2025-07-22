# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EmotionFilterOrder
      def self.register!(plugin)
        Emotions::LIST.each do |emotion|
          filter_order_emotion = ->(scope, order_direction, _guardian) do
            scope_period =
              scope
                .arel
                &.constraints
                &.flat_map(&:children)
                &.find do |node|
                  node.is_a?(Arel::Nodes::BoundSqlLiteral) &&
                    node.to_sql.match?(/topics\.bumped_at\s*>=/)
                end
                &.positional_binds
                &.first if scope.to_sql.include?("topics.bumped_at >=")

            if scope_period.is_a?(ActiveSupport::TimeWithZone)
              scope_period = "'#{scope_period.to_date}'"
            else
              # Fallback in case we can't find the scope period
              scope_period = "CURRENT_DATE - INTERVAL '1 year'"
            end

            emotion_clause = <<~SQL
              COUNT(*) FILTER (WHERE (classification_results.classification::jsonb->'#{emotion}')::float > 0.1)
            SQL

            # TODO: This is slow, we will need to materialize this in the future
            with_clause = <<~SQL
                SELECT
                    topics.id,
                    #{emotion_clause} AS emotion_#{emotion}
                FROM
                    topics
                INNER JOIN
                    posts ON posts.topic_id = topics.id
                INNER JOIN
                    classification_results ON
                    classification_results.target_id = posts.id AND
                    classification_results.target_type = 'Post' AND
                    classification_results.model_used = 'SamLowe/roberta-base-go_emotions'
                WHERE
                    topics.archetype = 'regular'
                    AND topics.deleted_at IS NULL
                    AND posts.deleted_at IS NULL
                    AND posts.post_type = 1
                    AND posts.created_at >= #{scope_period}
                GROUP BY
                    1
                HAVING
                    #{emotion_clause} > 0
            SQL

            scope
              .with(topic_emotion: Arel.sql(with_clause))
              .joins("INNER JOIN topic_emotion ON topic_emotion.id = topics.id")
              .order("topic_emotion.emotion_#{emotion} #{order_direction}")
          end
          plugin.add_filter_custom_filter("order:emotion_#{emotion}", &filter_order_emotion)
        end
      end
    end
  end
end
