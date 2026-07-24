# frozen_string_literal: true

module DiscourseWorkflows
  class PostSerializer < ApplicationSerializer
    attributes :id,
               :topic_id,
               :topic_title,
               :topic_slug,
               :post_number,
               :post_type,
               :reply_to_post_number,
               :post_url,
               :username,
               :user_id,
               :created_at,
               :updated_at,
               :excerpt,
               :like_count,
               :reply_count,
               :score,
               :category_id,
               :category_name,
               :author_group_ids,
               :author_group_names,
               :tags,
               :upload_ids,
               :raw,
               :cooked

    def initialize(object, opts)
      super
      @include_raw = opts.fetch(:include_raw, true)
      @include_cooked = opts.fetch(:include_cooked, false)
    end

    def topic_title
      topic&.title
    end

    def topic_slug
      topic&.slug
    end

    def post_url
      object.url
    end

    def username
      object.user&.username
    end

    def created_at
      object.created_at&.utc&.iso8601
    end

    def updated_at
      object.updated_at&.utc&.iso8601
    end

    def excerpt
      object.excerpt(300, strip_links: true, text_entities: true)
    end

    def category_id
      topic&.category_id
    end

    def category_name
      topic&.category&.name
    end

    def author_group_ids
      author_visible_groups.map(&:first)
    end

    def author_group_names
      author_visible_groups.map(&:last)
    end

    def tags
      return [] if topic.blank? || !SiteSetting.tagging_enabled

      topic.tags.visible(scope).pluck(:name)
    end

    def upload_ids
      object.upload_ids
    end

    def include_raw?
      @include_raw
    end

    def include_cooked?
      @include_cooked
    end

    private

    # Only expose the author's groups whose existence AND membership are visible
    # to the serializer's guardian, mirroring UserSerializer#groups. This keeps
    # hidden/private group membership from leaking through workflow outputs,
    # conditions, or logs when a post is serialized under a limited actor.
    # It returns an array of [id, name] pairs for the groups.
    # For example, [[1, "staff"], [2, "moderators"]].
    def author_visible_groups
      return @author_visible_groups if defined?(@author_visible_groups)

      @author_visible_groups =
        if object.user
          object
            .user
            .groups
            .visible_groups(scope&.user)
            .members_visible_groups(scope&.user)
            .pluck(:id, :name)
        else
          []
        end
    end

    def topic
      @topic ||= object.topic
    end
  end
end
