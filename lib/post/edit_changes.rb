# frozen_string_literal: true

class Post::EditChanges
  attr_reader :attributes

  def initialize(post:, topic:, guardian:, attributes:, topic_only:, editor:)
    @post = post
    @topic = topic
    @guardian = guardian
    @editor = editor
    @attributes = attributes.with_indifferent_access
    @topic_only = topic_only
  end

  def topic_attributes
    return {} unless @post.is_first_post?

    changes = attributes.slice(*PostRevisor.tracked_topic_fields.keys)
    changes.delete(:title) if changes[:title] == @topic.title
    changes.delete(:category_id) if changes[:category_id].to_i == @topic.category_id.to_i

    if changes.key?(:tags) &&
         (!Tag.include_tags? || PostRevisor.tag_change_noop?(@topic, changes[:tags]))
      changes.delete(:tags)
    end

    changes
  end

  def revision_attributes
    changes =
      (
        if @topic_only
          {}.with_indifferent_access
        else
          attributes.slice(
            :raw,
            :edit_reason,
            :locale,
            :reply_to_post_number,
            *Post.plugin_permitted_update_params.keys,
          )
        end
      )

    changes.merge!(topic_attributes)
    changes[:tags] = resolved_tag_names if changes.key?(:tags)
    changes.delete(:category_id) if @topic.shared_draft && category_changed?

    changes
  end

  def resolved_tag_names
    return @topic.tags.pluck(:name) unless attributes.key?(:tags)

    incoming = attributes[:tags] || []

    if incoming.first.is_a?(String)
      Discourse.deprecate(
        "Passing tag names as strings to the tags param is deprecated, use tag objects ({id, name}) instead",
        since: "2026.01",
        drop_from: "2026.07",
      )

      return incoming.reject(&:empty?)
    end

    ids = incoming.filter_map { |tag| tag[:id]&.to_i }

    incoming.filter_map { |tag| tag[:id].blank? && tag[:name].presence } +
      Tag.visible(@guardian).where(id: ids).pluck(:name)
  end

  def category_changed?
    topic_attributes.key?(:category_id)
  end

  def revision_requested?
    !@topic_only || revision_attributes.present?
  end

  def topic_edit_requested?
    @topic_only && topic_attributes.present?
  end

  def revision_options
    options = {}
    options[:validate_post] = false if @topic_only
    options[:keep_existing_draft] = attributes[:keep_existing_draft].to_s == "true" if @topic_only
    options[:skip_validations] = true if @post.post_type == Post.types[:small_action] &&
      @editor.staff?

    if attributes.key?(:bypass_bump) && @guardian.can_update_bumped_at?
      options[:bypass_bump] = ActiveModel::Type::Boolean.new.cast(attributes[:bypass_bump])
    end

    options
  end
end
