# frozen_string_literal: true

module DiscourseWorkflows
  class TopicSerializer < ApplicationSerializer
    include LocalizedFancyTopicTitleMixin
    include TopicTagsMixin

    attributes :id,
               :title,
               :slug,
               :posts_count,
               :reply_count,
               :highest_post_number,
               :created_at,
               :last_posted_at,
               :bumped,
               :bumped_at,
               :archetype,
               :visible,
               :closed,
               :archived,
               :has_summary,
               :views,
               :like_count,
               :category_id,
               :user_id,
               :last_post_user_id,
               :last_poster_username,
               :first_post_id,
               :pinned_globally,
               :featured_link,
               :featured_link_root_domain,
               :pinned,
               :unpinned,
               :excerpt,
               :posters,
               :participants,
               :custom_fields

    def initialize(object, opts)
      super
      @custom_field_names =
        Array(opts.fetch(:custom_field_names, []))
          .filter_map { |name| name.to_s.strip.presence }
          .uniq
    end

    def created_at
      object.created_at&.utc&.iso8601
    end

    def last_posted_at
      object.last_posted_at&.utc&.iso8601
    end

    def bumped_at
      object.bumped_at&.utc&.iso8601
    end

    def bumped
      object.created_at.present? && object.bumped_at.present? &&
        object.created_at < object.bumped_at
    end

    def last_poster_username
      topic_posters.find { |poster| poster.user&.id == object.last_post_user_id }&.user&.username ||
        object.last_poster&.username
    end

    def first_post_id
      object.first_post&.id
    end

    def pinned
      PinnedCheck.pinned?(object, object.user_data)
    end

    def unpinned
      PinnedCheck.unpinned?(object, object.user_data)
    end

    def posters
      topic_posters.map { |poster| serialize_topic_poster(poster) }
    end

    def participants
      return [] if !object.private_message?

      (object.participants || object.participants_summary || []).map do |participant|
        serialize_topic_poster(participant)
      end
    end

    def include_participants?
      object.private_message?
    end

    def custom_fields
      if object.custom_fields_preloaded?
        return object.preloaded_custom_fields.slice(*@custom_field_names)
      end

      @custom_field_names.each_with_object(
        ActiveSupport::HashWithIndifferentAccess.new,
      ) { |name, fields| fields[name] = object.custom_fields[name] }
    end

    def include_custom_fields?
      @custom_field_names.present?
    end

    def include_featured_link?
      SiteSetting.topic_featured_link_enabled
    end

    def include_featured_link_root_domain?
      SiteSetting.topic_featured_link_enabled && object.featured_link.present?
    end

    private

    def topic_posters
      @topic_posters ||= object.posters || object.posters_summary || []
    end

    def serialize_topic_poster(topic_poster)
      {
        extras: topic_poster.extras,
        description: topic_poster.description,
        user_id: topic_poster.user&.id,
        primary_group_id: topic_poster.primary_group&.id,
        flair_group_id: topic_poster.flair_group&.id,
      }.compact
    end
  end
end
