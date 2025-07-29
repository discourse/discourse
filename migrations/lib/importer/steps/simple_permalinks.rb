# frozen_string_literal: true

module Migrations::Importer::Steps
  class SimplePermalinks < ::Migrations::Importer::CopyStep
    depends_on :users, :topics, :posts, :tags, :categories

    requires_set :existing_permalinks, "SELECT url FROM permalinks"

    table_name :permalinks
    column_names %i[
                   url
                   category_id
                   created_at
                   updated_at
                   external_url
                   post_id
                   tag_id
                   topic_id
                   user_id
                 ]

    total_rows_query <<~SQL
      SELECT COUNT(*)
      FROM permalinks
           LEFT JOIN permalink_placeholders ON permalinks.url = permalink_placeholders.url
      WHERE permalink_placeholders.url IS NULL
    SQL

    rows_query <<~SQL,
      SELECT permalinks.*,
             mapped_users.discourse_id AS discourse_user_id,
             mapped_topics.discourse_id AS discourse_topic_id,
             mapped_posts.discourse_id AS discourse_post_id,
             mapped_tags.discourse_id AS discourse_tag_id,
             mapped_categories.discourse_id AS discourse_category_id
      FROM permalinks
           LEFT JOIN mapped.ids mapped_users
             ON permalinks.user_id = mapped_users.original_id AND mapped_users.type = ?1
           LEFT JOIN mapped.ids mapped_topics
             ON permalinks.topic_id = mapped_topics.original_id AND mapped_topics.type = ?2
           LEFT JOIN mapped.ids mapped_posts
             ON permalinks.post_id = mapped_posts.original_id AND mapped_posts.type = ?3
           LEFT JOIN mapped.ids mapped_tags
             ON permalinks.tag_id = mapped_tags.original_id AND mapped_tags.type = ?4
           LEFT JOIN mapped.ids mapped_categories
             ON permalinks.category_id = mapped_categories.original_id AND mapped_categories.type = ?5
           LEFT JOIN permalink_placeholders
             ON permalinks.url = permalink_placeholders.url
      WHERE permalink_placeholders.url IS NULL
      ORDER BY permalinks.url
    SQL
               MappingType::USERS,
               MappingType::TOPICS,
               MappingType::POSTS,
               MappingType::TAGS,
               MappingType::CATEGORIES

    private

    def transform_row(row)
      return nil unless @existing_permalinks.add?(row[:url])

      found_target =
        (row[:topic_id] = row[:discourse_topic_id]) || (row[:post_id] = row[:discourse_post_id]) ||
          (row[:category_id] = row[:discourse_category_id]) ||
          (row[:tag_id] = row[:discourse_tag_id]) || (row[:user_id] = row[:discourse_user_id]) ||
          row[:external_url]

      unless found_target
        puts "    Permalink '#{row[:url]}' has no valid target"
        return nil
      end

      super
    end
  end
end
