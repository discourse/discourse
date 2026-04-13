# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas
    class Topic
      BASE_FIELDS = {
        id: :integer,
        title: :string,
        raw: :string,
        username: :string,
        user_id: :integer,
        tags: :array,
        category_id: :integer,
        archetype: :string,
        created_at: :string,
        bumped_at: :string,
        posts_count: :integer,
        views: :integer,
        like_count: :integer,
        status: :string,
      }.freeze

      def self.fields
        extensions = Registry.schema_extensions_for(:topic)
        extensions.reduce(BASE_FIELDS.dup) { |schema, ext| schema.merge(ext[:fields]) }
      end

      def self.resolve(topic)
        first_post = topic.first_post

        data = {
          id: topic.id,
          title: topic.title,
          raw: first_post&.raw,
          username: first_post&.user&.username,
          user_id: topic.user_id,
          tags: topic.tags.pluck(:name),
          category_id: topic.category_id,
          archetype: topic.archetype,
          created_at: topic.created_at&.iso8601,
          bumped_at: topic.bumped_at&.iso8601,
          posts_count: topic.posts_count,
          views: topic.views,
          like_count: topic.like_count,
          status: topic_status(topic),
        }

        extensions = Registry.schema_extensions_for(:topic)
        extensions.each { |ext| data.merge!(ext[:resolver].call(topic)) }
        data
      end

      def self.topic_status(topic)
        if topic.archived
          "archived"
        elsif topic.closed
          "closed"
        else
          "open"
        end
      end
    end
  end
end
