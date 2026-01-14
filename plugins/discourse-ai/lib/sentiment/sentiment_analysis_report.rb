# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentAnalysisReport
      include Constants
      GROUP_BY_FILTER_DEFAULT = :category
      SORT_BY_FILTER_DEFAULT = :size

      def self.register!(plugin)
        plugin.add_report("sentiment_analysis") do |report|
          report.modes = [:sentiment_analysis]

          group_by_filter = report.filters.dig(:group_by) || GROUP_BY_FILTER_DEFAULT
          report.add_filter(
            "group_by",
            type: "list",
            default: group_by_filter,
            choices: [{ id: "category", name: "Category" }, { id: "tag", name: "Tag" }],
            allow_any: false,
            auto_insert_none_item: false,
          )

          size_filter = report.filters.dig(:sort_by) || SORT_BY_FILTER_DEFAULT
          report.add_filter(
            "sort_by",
            type: "list",
            default: size_filter,
            choices: [{ id: "size", name: "Size" }, { id: "alphabetical", name: "Alphabetical" }],
            allow_any: false,
            auto_insert_none_item: false,
          )

          category_id, include_subcategories =
            report.add_category_filter(disabled: group_by_filter.to_sym == :tag)

          tag_filter = report.filters.dig(:tag) || "any"
          tag_choices =
            Tag
              .all
              .map { |tag| { id: tag.name, name: tag.name } }
              .unshift({ id: "any", name: "Any" })
          report.add_filter(
            "tag",
            type: "list",
            default: tag_filter,
            choices: tag_choices,
            allow_any: false,
            auto_insert_none_item: false,
            disabled: group_by_filter.to_sym == :category,
          )

          opts = { category_id: category_id, include_subcategories: include_subcategories }
          sentiment_data = DiscourseAi::Sentiment::SentimentAnalysisReport.fetch_data(report, opts)

          report.data = sentiment_data
          report.labels = [
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.positive"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.neutral"),
            I18n.t("discourse_ai.sentiment.reports.sentiment_analysis.negative"),
          ]
        end
      end

      def self.fetch_data(report, opts)
        threshold = SENTIMENT_THRESHOLD

        grouping = (report.filters.dig(:group_by) || GROUP_BY_FILTER_DEFAULT).to_sym
        sorting = (report.filters.dig(:sort_by) || SORT_BY_FILTER_DEFAULT).to_sym
        category_filter = report.filters.dig(:category)
        tag_filter = report.filters.dig(:tag)

        sentiment_count_sql = Proc.new { |sentiment| <<~SQL }
          COUNT(
            CASE WHEN (cr.classification::jsonb->'#{sentiment}')::float > :threshold THEN 1 ELSE NULL END
          )
        SQL

        grouping_clause =
          case grouping
          when :category
            <<~SQL
                c.id AS category_id,
                c.name AS category_name,
              SQL
          when :tag
            <<~SQL
                  tags.name AS tag_name,
              SQL
          else
            raise Discourse::InvalidParameters
          end

        group_by_clause =
          case grouping
          when :category
            "GROUP BY c.id, c.name"
          when :tag
            "GROUP BY tags.name"
          else
            raise Discourse::InvalidParameters
          end

        grouping_join =
          case grouping
          when :category
            <<~SQL
              INNER JOIN categories c ON c.id = t.category_id
            SQL
          when :tag
            <<~SQL
              INNER JOIN topic_tags tt ON tt.topic_id = p.topic_id
              INNER JOIN tags ON tags.id = tt.tag_id
            SQL
          else
            raise Discourse::InvalidParameters
          end

        order_by_clause =
          case sorting
          when :size
            "ORDER BY total_count DESC"
          when :alphabetical
            "ORDER BY 1 ASC"
          else
            raise Discourse::InvalidParameters
          end

        where_clause =
          case grouping
          when :category
            if category_filter.nil?
              ""
            elsif opts[:include_subcategories]
              <<~SQL
                AND (c.id = :category_filter OR c.parent_category_id = :category_filter)
              SQL
            else
              "AND c.id = :category_filter"
            end
          when :tag
            if tag_filter.nil? || tag_filter == "any"
              ""
            else
              "AND tags.name = :tag_filter"
            end
          end

        grouped_sentiments =
          DB.query(
            <<~SQL,
              SELECT
                #{grouping_clause}
                #{sentiment_count_sql.call("positive")} AS positive_count,
                #{sentiment_count_sql.call("negative")} AS negative_count,
                COUNT(*) AS total_count
              FROM
                classification_results AS cr
              INNER JOIN posts p ON p.id = cr.target_id AND cr.target_type = 'Post'
              INNER JOIN topics t ON t.id = p.topic_id
              #{grouping_join}
              WHERE
                t.archetype = 'regular' AND
                p.user_id > 0 AND
                cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest' AND
                (p.created_at > :report_start AND p.created_at < :report_end)
                #{where_clause}
              #{group_by_clause}
              #{order_by_clause}
            SQL
            report_start: report.start_date,
            report_end: report.end_date,
            threshold: threshold,
            category_filter: category_filter,
            tag_filter: tag_filter,
          )

        grouped_sentiments
      end
    end
  end
end
