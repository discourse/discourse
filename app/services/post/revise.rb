# frozen_string_literal: true

# Saves permitted edits to a post or its topic, reporting invalid or conflicting changes.
#
# Pass guardian for authorization and editor for revision attribution. Params must contain
# either post_id or topic_id; changes defaults to an empty hash. A topic_id edit targets
# the first post for revision history but leaves its body unchanged.
#
# Accepted changes:
# * raw, edit_reason, locale, reply_to_post_number: content and metadata for post_id edits.
# * title, category_id, tags, featured_link, archetype: topic details, applied only to
#   the first post. Tags accept [{ id: 123 }, { name: "new-tag" }]; nil or [] clears tags.
#   Legacy arrays of tag name strings are also accepted.
# * original_text, original_title, original_tags: optional conflict checks against
#   current values. original_tags uses [{ id: 123 }]. Blank originals skip their checks.
# * image_sizes: image dimensions supplied by the editor.
# * bypass_bump: boolean or boolean string, honored only when the guardian permits it.
# * keep_existing_draft: boolean or boolean string, preserves the editor's existing draft.
# Registered plugin post and topic fields are also accepted.
#
# Outcome callbacks:
# * on_success: post, topic, and category_changed are available.
# * on_failed_contract: missing identifiers or invalid changes.
# * on_model_not_found(:post) or (:topic): the requested content was not found.
# * on_failed_policy: can_edit_post, can_edit_topic_record, can_edit_topic, or
#   can_edit_tags identifies the denied permission.
# * on_failed_step(:check_edit_conflicts): an original value no longer matches.
# * on_failed_step(:validate_category_change): topic.errors and status describe rejection.
# * on_failed_step(:revise_post): post.errors or topic.errors describe invalid edits.
# * on_failure: fallback for an outcome without a more specific handler.
#
# Post::Revise.call(
#   params: {
#     post_id: post.id,
#     changes: { raw: "The corrected text of this post.", original_text: post.raw },
#   },
#   guardian: editor.guardian,
#   editor:,
# ) do
#   on_success { |post:| render_serialized(post, PostUpdateSerializer) }
#   on_failed_contract { raise Discourse::InvalidParameters }
#   on_failed_step(:check_edit_conflicts) { render_json_error(I18n.t("edit_conflict"), status: 409) }
# end
class Post::Revise
  include Service::Base

  class EditConflict < StandardError
  end

  params do
    attribute :post_id, :integer
    attribute :topic_id, :integer
    attribute :changes, default: -> { {} }

    validates :post_id, presence: true, unless: :topic_id
    validates :topic_id, absence: true, if: :post_id

    validate :valid_changes

    private

    def valid_changes
      unless changes.is_a?(Hash)
        errors.add(:changes, :invalid)
        return
      end

      %i[tags original_tags].each do |key|
        tags = changes[key]
        next if tags.nil?

        errors.add(:changes, :invalid) unless valid_tags?(tags)
      end
    end

    def valid_tags?(tags)
      return false unless tags.is_a?(Array)
      return true if tags.all? { |tag| tag.is_a?(String) }

      tags.all? { |tag| valid_tag?(tag) }
    end

    def valid_tag?(tag)
      return false unless tag.is_a?(Hash)
      return false unless tag[:name].nil? || tag[:name].is_a?(String)

      id = tag[:id]
      return tag[:name].present? if id.nil? || (id.is_a?(String) && id.blank?)

      id.to_s.match?(/\A[1-9]\d*\z/)
    end
  end

  model :topic
  policy :can_edit_topic_record
  model :post
  policy :can_edit_post
  step :prepare_changes
  policy :can_edit_topic
  policy :can_edit_tags
  step :check_edit_conflicts

  only_if :category_changed? do
    step :validate_category_change

    only_if :shared_draft? do
      step :update_shared_draft_destination
    end
  end

  only_if :revision_requested? do
    step :revise_post
  end

  private

  def fetch_post(params:, guardian:)
    posts = guardian.is_staff? ? Post.with_deleted : Post.all

    if params.topic_id
      posts.where(topic_id: params.topic_id).order(:post_number).first
    else
      posts.find_by(id: params.post_id)
    end
  end

  def fetch_topic(params:, guardian:)
    topics = guardian.is_staff? && params.topic_id.blank? ? Topic.with_deleted : Topic.all
    posts = guardian.is_staff? ? Post.with_deleted : Post.all
    topic_id = params.topic_id || posts.where(id: params.post_id).pick(:topic_id)

    topics.find_by(id: topic_id)
  end

  def can_edit_topic_record(params:, topic:, guardian:)
    params.topic_id.blank? || guardian.can_edit?(topic)
  end

  def can_edit_post(params:, post:, guardian:)
    params.topic_id.present? || guardian.can_edit?(post)
  end

  def prepare_changes(params:, post:, topic:, guardian:)
    attributes = params.changes.with_indifferent_access
    topic_changes = topic_attributes(attributes:, post:, topic:)
    revision_changes =
      if params.topic_id.present?
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

    revision_changes.merge!(topic_changes)

    tag_names =
      if revision_changes.key?(:tags) || topic_changes.key?(:category_id)
        resolve_tag_names(attributes:, topic:, guardian:)
      end

    # resolve to name strings before passing to PostRevisor
    revision_changes[:tags] = tag_names if revision_changes.key?(:tags)
    revision_changes.delete(:category_id) if topic.shared_draft && topic_changes.key?(:category_id)

    context[:topic_changes] = topic_changes
    context[:revision_changes] = revision_changes
    context[:tag_names] = tag_names
  end

  def topic_attributes(attributes:, post:, topic:)
    # to stay consistent with the create api, we allow for title & category changes here
    return {} unless post.is_first_post?

    changes = attributes.slice(*PostRevisor.tracked_topic_fields.keys)
    changes.delete(:title) if changes[:title] == topic.title
    changes.delete(:category_id) if changes[:category_id].to_i == topic.category_id.to_i

    if changes.key?(:tags) &&
         (!Tag.include_tags? || PostRevisor.tag_change_noop?(topic, changes[:tags]))
      changes.delete(:tags)
    end

    changes
  end

  def resolve_tag_names(attributes:, topic:, guardian:)
    return topic.tags.pluck(:name) unless attributes.key?(:tags)

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
      Tag.visible(guardian).where(id: ids).pluck(:name)
  end

  def can_edit_topic(params:, topic_changes:, topic:, guardian:)
    return true if params.topic_id.present?

    topic_changes.except(:tags).empty? || guardian.can_edit_topic?(topic)
  end

  def can_edit_tags(topic_changes:, topic:, guardian:)
    !topic_changes.key?(:tags) || guardian.can_edit_tags?(topic)
  end

  def check_edit_conflicts(params:, post:, topic:)
    originals = params.changes
    conflict = originals[:original_text].present? && originals[:original_text] != post.raw

    if post.is_first_post?
      conflict ||= originals[:original_title].present? && originals[:original_title] != topic.title
      tag_ids = originals[:original_tags]&.map { |tag| tag.is_a?(String) ? 0 : tag[:id].to_i }&.sort
      conflict ||= tag_ids.present? && tag_ids != topic.tags.pluck(:id).sort
    end

    fail!(I18n.t("edit_conflict")) if conflict
  end

  def category_changed?(topic_changes:)
    topic_changes.key?(:category_id)
  end

  def shared_draft?(topic:)
    topic.shared_draft.present?
  end

  def revision_requested?(params:, revision_changes:)
    params.topic_id.blank? || revision_changes.present?
  end

  def validate_category_change(topic_changes:, tag_names:, topic:, guardian:)
    result =
      TopicCategoryChangeValidator.call(
        topic:,
        category_id: topic_changes[:category_id],
        guardian:,
        tag_names:,
        tags_changed: topic_changes.key?(:tags),
      )

    return if result.success?

    topic.errors.add(:base, result.error)
    context[:status] = result.status
    fail!(result.error)
  end

  def update_shared_draft_destination(topic_changes:, topic:)
    topic.shared_draft.update!(category_id: topic_changes[:category_id])
  end

  def revise_post(params:, topic_changes:, revision_changes:, post:, topic:, guardian:, editor:)
    post.image_sizes = params.changes[:image_sizes] if params.changes[:image_sizes].present?

    revisor = PostRevisor.new(post, topic)
    topic_edit_requested = params.topic_id.present? && topic_changes.present?
    category_changed = topic_changes.key?(:category_id)
    revised =
      revisor.revise!(
        editor,
        revision_changes,
        revision_options(params:, post:, guardian:, editor:),
      )
    context[:category_changed] = revisor.category_changed

    if topic.errors.present?
      errors =
        TopicCategoryChangeValidator.safe_revision_errors(topic:, guardian:, category_changed:)
      topic.errors.clear
      errors.each { |error| topic.errors.add(:base, error) }
    end

    if (revisor.successfully_saved_post_and_topic == false || (!revised && topic_edit_requested)) &&
         post.errors.empty? && topic.errors.empty?
      topic.errors.add(:base, :unable_to_update)
    end

    if post.errors.present? || topic.errors.present?
      fail!(post.errors.full_messages + topic.errors.full_messages)
    end
  end

  def revision_options(params:, post:, guardian:, editor:)
    attributes = params.changes
    options = { keep_existing_draft: attributes[:keep_existing_draft].to_s == "true" }
    options[:validate_post] = false if params.topic_id.present?

    # We don't need to validate edits to small action posts by staff
    options[:skip_validations] = true if post.post_type == Post.types[:small_action] &&
      editor.staff?

    if attributes.key?(:bypass_bump) && guardian.can_update_bumped_at?
      options[:bypass_bump] = ActiveModel::Type::Boolean.new.cast(attributes[:bypass_bump])
    end

    options
  end
end
