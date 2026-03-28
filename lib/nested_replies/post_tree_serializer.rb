# frozen_string_literal: true

module NestedReplies
  class PostTreeSerializer
    def initialize(topic:, topic_view:, guardian:)
      @topic = topic
      @topic_view = topic_view
      @guardian = guardian
    end

    def serialize_topic
      serializer = TopicViewSerializer.new(@topic_view, scope: @guardian, root: false)
      json = serializer.as_json
      json.except(:post_stream, :timeline_lookup, :user_badges)
    end

    def serialize_post(post, reply_counts, descendant_counts = {})
      post.topic = @topic
      serializer = PostSerializer.new(post, scope: @guardian, root: false)
      serializer.topic_view = @topic_view
      json = serializer.as_json

      json[:direct_reply_count] = reply_counts[post.post_number] || 0
      json[:total_descendant_count] = descendant_counts[post.id] || 0

      if post.deleted_at.present?
        json[:deleted_post_placeholder] = true
        json[:cooked] = ""
        json[:raw] = nil
        json[:actions_summary] = []
        unless @guardian.is_staff?
          json =
            json.slice(
              :id,
              :post_number,
              :reply_to_post_number,
              :deleted_post_placeholder,
              :cooked,
              :raw,
              :actions_summary,
              :direct_reply_count,
              :total_descendant_count,
            )
        end
      end

      json
    end

    def serialize_tree(post, children_map, reply_counts, descendant_counts = {})
      node = serialize_post(post, reply_counts, descendant_counts)
      children = children_map[post.post_number] || []
      node[:children] = children.map do |child|
        serialize_tree(child, children_map, reply_counts, descendant_counts)
      end
      node
    end
  end
end
