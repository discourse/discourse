# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class SharedConversationsQuery
      PAGE_SIZE = 20
      ORDERS = %w[newest oldest].freeze

      def initialize(user:, order:, cursor:)
        @user = user
        @order = order.nil? ? "newest" : order
        @raw_cursor = cursor
      end

      def call
        raise Discourse::InvalidParameters.new(:order) if !ORDERS.include?(@order)

        cursor = parse_cursor(@raw_cursor) if !@raw_cursor.nil?
        direction = @order == "newest" ? :desc : :asc
        scope = SharedAiConversation.where(user: @user, target_type: "Topic")
        if cursor
          operator = @order == "newest" ? "<" : ">"
          scope =
            scope.where(
              "created_at #{operator} :time OR (created_at = :time AND id #{operator} :id)",
              time: cursor[:created_at],
              id: cursor[:id],
            )
        end

        rows =
          scope
            .includes(:user)
            .order(created_at: direction, id: direction)
            .limit(PAGE_SIZE + 1)
            .to_a
        has_more = rows.length > PAGE_SIZE
        page = rows.first(PAGE_SIZE)
        items = build_items(page)
        { items: items, has_more: has_more, next_cursor: has_more ? position(page.last) : nil }
      end

      private

      def parse_cursor(raw)
        raise Discourse::InvalidParameters.new(:cursor) if !raw.is_a?(String) || raw.bytesize > 512

        value = JSON.parse(raw)
        if !value.is_a?(Hash) || value.keys.sort != %w[created_at id order] ||
             value["order"] != @order || !value["id"].is_a?(Integer) ||
             !value["id"].between?(1, 2**63 - 1) || !value["created_at"].is_a?(String) ||
             !value["created_at"].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/)
          raise Discourse::InvalidParameters.new(:cursor)
        end

        { created_at: Time.iso8601(value["created_at"]), id: value["id"] }
      rescue JSON::ParserError, ArgumentError
        raise Discourse::InvalidParameters.new(:cursor)
      end

      def position(row)
        { order: @order, created_at: row.created_at.utc.iso8601(6), id: row.id }
      end

      def build_items(page)
        topics_by_id = Topic.includes(:category).where(id: page.map(&:target_id)).index_by(&:id)
        context_post_ids = page.flat_map { |row| row.context.filter_map { |post| post["id"] } }.uniq
        posts_by_id =
          Post
            .includes(topic: :category)
            .where(id: context_post_ids, topic_id: topics_by_id.keys)
            .index_by(&:id)
        page.map do |row|
          topic = topics_by_id[row.target_id]
          available =
            topic.present? && row.publicly_visible?(topic: topic, posts_by_id: posts_by_id)
          {
            id: row.id,
            share_key: row.share_key,
            title: row.title,
            url: row.url,
            created_at: row.created_at,
            available: !!available,
          }
        end
      end
    end
  end
end
