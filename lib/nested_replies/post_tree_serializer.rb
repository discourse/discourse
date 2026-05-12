# frozen_string_literal: true

module NestedReplies
  class PostTreeSerializer
    def initialize(topic:, topic_view:, guardian:)
      @topic = topic
      @topic_view = topic_view
      @guardian = guardian
      @ignored_user_ids = IgnoredUser.ignored_ids_for(guardian.user)
    end

    SUGGESTED_AND_RELATED_KEYS = %i[
      suggested_topics
      suggested_group_name
      related_topics
      related_messages
    ].freeze

    def serialize_topic
      topic_view_json.merge(has_activity_log: activity_log_present?).except(
        :post_stream,
        :timeline_lookup,
        :user_badges,
        *SUGGESTED_AND_RELATED_KEYS,
      )
    end

    # Produces the suggested/related payload we piggyback on whichever
    # response has has_more_roots=false — mirroring how the flat view
    # ships suggested_topics on the final /t/:id/posts.json chunk.
    def serialize_suggested_and_related
      topic_view_json.slice(*SUGGESTED_AND_RELATED_KEYS)
    end

    def serialize_post(post, reply_counts, descendant_counts = {})
      # Assign the already-loaded topic to avoid an N+1 query per post
      # in PostSerializer#topic, which reads object.topic.
      post.topic = @topic
      serializer = PostSerializer.new(post, scope: @guardian, root: false)
      serializer.topic_view = @topic_view
      json = serializer.as_json

      json[:direct_reply_count] = reply_counts[post.post_number] || 0
      json[:total_descendant_count] = descendant_counts[post.id] || 0

      if post.deleted_at.present?
        json[:deleted_post_placeholder] = true
        unless @guardian.is_staff?
          json[:cooked] = ""
          json[:raw] = nil
          json[:actions_summary] = []
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
      elsif post.post_number != 1 && @ignored_user_ids.include?(post.user_id)
        json[:ignored_post_placeholder] = true
        json[:cooked] = ""
        json[:raw] = nil
        json[:actions_summary] = []
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

    private

    def topic_view_json
      @topic_view_json ||=
        TopicViewSerializer.new(@topic_view, scope: @guardian, root: false).as_json
    end

    # Filters mirror Guardian#can_see_post? so the boolean does not leak
    # the existence of small_actions/whispers the user cannot see.
    def activity_log_present?
      post_types = [Post.types[:small_action]]
      post_types << Post.types[:whisper] if @guardian.user&.whisperer?

      scope = @topic.posts.where(post_type: post_types).where.not(action_code: [nil, ""])
      scope = scope.where(hidden: false) unless can_see_hidden_posts?
      scope.exists?
    end

    def can_see_hidden_posts?
      return true if @guardian.is_staff?
      if SiteSetting.hidden_post_visible_groups_map.include?(Group::AUTO_GROUPS[:everyone])
        return true
      end
      return false if @guardian.anonymous?
      @guardian.user.in_any_groups?(SiteSetting.hidden_post_visible_groups_map)
    end
  end
end
