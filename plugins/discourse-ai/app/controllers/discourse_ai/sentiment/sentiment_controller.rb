# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentController < ::Admin::StaffController
      include Constants
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      DEFAULT_POSTS_LIMIT = 50
      MAX_POSTS_LIMIT = 100

      def posts
        group_by = params.required(:group_by)&.to_sym
        group_value = params.required(:group_value).presence
        start_date = params[:start_date].presence
        end_date = params[:end_date]
        threshold = SENTIMENT_THRESHOLD

        raise Discourse::InvalidParameters if %i[category tag].exclude?(group_by)

        limit = fetch_limit_from_params(default: DEFAULT_POSTS_LIMIT, max: MAX_POSTS_LIMIT)
        offset = params[:offset].to_i || 0

        case group_by
        when :category
          grouping_clause = "c.name"
          grouping_join = "" # categories already joined
        when :tag
          grouping_clause = "tags.name"
          grouping_join =
            "INNER JOIN topic_tags tt ON tt.topic_id = p.topic_id INNER JOIN tags ON tags.id = tt.tag_id"
        end

        posts =
          DB.query(
            <<~SQL,
          SELECT
            p.id AS post_id,
            p.topic_id,
            t.fancy_title AS topic_title,
            p.cooked as post_cooked,
            p.user_id,
            p.post_number,
            p.created_at AS created_at,
            u.username,
            u.name,
            u.uploaded_avatar_id,
            c.id AS category_id,
            (CASE 
              WHEN (cr.classification::jsonb->'positive')::float > :threshold THEN 'positive'
              WHEN (cr.classification::jsonb->'negative')::float > :threshold THEN 'negative'
              ELSE 'neutral'
            END) AS sentiment
          FROM posts p
          INNER JOIN topics t ON t.id = p.topic_id
          INNER JOIN classification_results cr ON cr.target_id = p.id AND cr.target_type = 'Post'
          LEFT JOIN users u ON u.id = p.user_id
          LEFT JOIN categories c ON c.id = t.category_id
          #{grouping_join}
          WHERE
            #{grouping_clause} = :group_value AND
            t.archetype = 'regular' AND
            p.user_id > 0 AND
            cr.model_used = 'cardiffnlp/twitter-roberta-base-sentiment-latest' AND
            ((:start_date IS NULL OR p.created_at > :start_date) AND (:end_date IS NULL OR p.created_at < :end_date))
            AND p.deleted_at IS NULL
          ORDER BY p.created_at DESC
          LIMIT :limit OFFSET :offset
        SQL
            group_value: group_value,
            start_date: start_date,
            end_date: end_date,
            threshold: threshold,
            limit: limit + 1,
            offset: offset,
          )

        has_more = posts.length > limit
        posts.pop if has_more

        render_json_dump(
          posts:
            serialize_data(
              posts,
              AiSentimentPostSerializer,
              scope: guardian,
              add_raw: true,
              add_excerpt: true,
              add_title: true,
            ),
          has_more: has_more,
          next_offset: has_more ? offset + limit : nil,
        )
      end
    end
  end
end
