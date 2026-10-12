# frozen_string_literal: true

# Saves post revisions, reporting invalid or conflicting changes.
class Post::Revise
  include Service::Base

  class EditConflict < StandardError
  end

  class RevisionContract < Service::ContractBase
    attribute :changes, default: -> { {} }

    before_validation :normalize_changes

    validate :valid_changes

    private

    def normalize_changes
      self.changes = changes.to_unsafe_h.deep_symbolize_keys if changes.respond_to?(:to_unsafe_h)
    end

    def valid_changes
      unless changes.is_a?(Hash)
        errors.add(:changes, :invalid)
        return
      end

      %i[
        raw
        original_text
        edit_reason
        locale
        title
        original_title
        category_id
        featured_link
        archetype
        reply_to_post_number
        bypass_bump
        keep_existing_draft
      ].each do |key|
        value = changes[key]
        errors.add(:changes, :invalid) if value.is_a?(Array) || value.is_a?(Hash)
      end

      if changes.key?(:image_sizes) && !changes[:image_sizes].is_a?(Hash)
        errors.add(:changes, :invalid)
      end

      %i[tags original_tags].each do |key|
        tags = changes[key]
        next if tags.nil? || (key == :tags && tags == "")

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

  # @!method self.call(guardian:, editor:, params:, options: {})
  #   @param guardian [Guardian] permissions of the person editing
  #   @param editor [User] person credited with the revision
  #   @param options [Hash] revision behavior
  #   @option options [Boolean] :topic_revision (false) revise only topic fields using topic
  #     permissions, preserving the post body and its validation state
  #   @param params [Hash] revision inputs
  #   @option params [Integer] :post_id post to revise
  #   @option params [Hash, ActionController::Parameters] :changes ({}) fields to change
  #   @option params.changes [String] :raw post body, used with post_id
  #   @option params.changes [String] :edit_reason revision explanation, used with post_id
  #   @option params.changes [String] :locale content locale, used with post_id
  #   @option params.changes [Integer] :reply_to_post_number reply target, used with post_id
  #   @option params.changes [String] :title topic title, applied only to the first post
  #   @option params.changes [Integer] :category_id destination category, applied only to the first post
  #   @option params.changes [String] :featured_link topic link, applied only to the first post
  #   @option params.changes [String] :archetype topic archetype, applied only to the first post
  #   @option params.changes [Array<Hash>, Array<String>, nil] :tags topic tags as
  #     [{ id: 123 }, { name: "new-tag" }] or legacy names. nil, [] or "" clears tags.
  #     Applied only to the first post.
  #   @option params.changes [String] :original_text expected body; blank skips the conflict check
  #   @option params.changes [String] :original_title expected title; blank skips the conflict check
  #   @option params.changes [Array<Hash>] :original_tags expected tags as [{ id: 123 }];
  #     blank skips the conflict check
  #   @option params.changes [Hash] :image_sizes image dimensions supplied by the editor
  #   @option params.changes [Boolean, String] :bypass_bump preserve topic bump time when permitted
  #   @option params.changes [Boolean, String] :keep_existing_draft preserve the editor's existing draft
  #   @note Registered plugin post and topic fields are also accepted in changes.
  #   @return [Service::Base::Context] service result when called without an outcome block
  #   @yield Register outcome handlers through {Service::Runner}:
  #     * on_success: exposes post, topic, and category_changed.
  #     * on_failed_contract: missing identifiers or invalid changes.
  #     * on_model_not_found(:post) or (:topic): content was not found.
  #     * on_failed_policy: can_edit_post, can_edit_topic,
  #       or can_edit_tags identifies the denied permission.
  #     * on_failed_step(:validate_tag_count): post.errors describes the tag limit.
  #     * on_failed_step(:check_edit_conflicts): an original value no longer matches.
  #     * on_failed_step(:validate_category_change): topic.errors and status describe rejection.
  #     * on_failed_step(:revise_post): post.errors or topic.errors describe invalid edits.
  #     * on_failure: fallback for an outcome without a more specific handler.
  #   @example Edit a post and handle a conflict
  #     Post::Revise.call(
  #       params: {
  #         post_id: post.id,
  #         changes: { raw: "The corrected text of this post.", original_text: post.raw },
  #       },
  #       guardian: editor.guardian,
  #       editor:,
  #     ) do
  #       on_success { |post:| render_serialized(post, PostUpdateSerializer) }
  #       on_failed_contract { raise Discourse::InvalidParameters }
  #       on_failed_step(:check_edit_conflicts) { render_json_error(I18n.t("edit_conflict"), status: 409) }
  #     end

  params(base_class: RevisionContract) do
    attribute :post_id, :integer

    validates :post_id, presence: true
  end

  options { attribute :topic_revision, :boolean, default: false }

  model :topic
  model :post
  policy :can_edit_post
  step :validate_tag_count
  step :prepare_changes
  policy :can_edit_topic
  policy :can_edit_tags
  step :check_edit_conflicts

  only_if :category_changed? do
    step :validate_category_change
  end

  step :revise_post

  private

  def fetch_post(params:, guardian:)
    posts = guardian.is_staff? ? Post.with_deleted : Post.all

    posts.find_by(id: params.post_id)
  end

  def fetch_topic(params:, guardian:)
    topics = guardian.is_staff? ? Topic.with_deleted : Topic.all
    posts = guardian.is_staff? ? Post.with_deleted : Post.all

    topics.find_by(id: posts.where(id: params.post_id).pick(:topic_id))
  end

  def can_edit_post(post:, topic:, guardian:, options:)
    options.topic_revision ? guardian.can_edit?(topic) : guardian.can_edit?(post)
  end

  def validate_tag_count(params:, post:)
    %i[tags original_tags].each do |key|
      tags = params.changes[key]
      next unless tags.is_a?(Array) && tags.size > SiteSetting.max_tags_per_topic

      post.errors.add(
        :base,
        I18n.t("tags.too_many_tags_for_topic", count: SiteSetting.max_tags_per_topic),
      )
      fail!(post.errors.full_messages)
    end
  end

  def prepare_changes(params:, post:, topic:, guardian:, options:)
    attributes = params.changes.with_indifferent_access
    attributes[:tags] = nil if attributes[:tags] == ""
    topic_changes = topic_attributes(attributes:, post:, topic:)
    revision_changes =
      if options.topic_revision
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

  def can_edit_topic(topic_changes:, topic:, guardian:, options:)
    return true if options.topic_revision

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

  def revise_post(
    params:,
    topic_changes:,
    revision_changes:,
    post:,
    topic:,
    guardian:,
    editor:,
    options:
  )
    post.image_sizes = params.changes[:image_sizes] if params.changes[:image_sizes].present?

    revisor = PostRevisor.new(post, topic)
    topic_edit_requested = options.topic_revision && topic_changes.present?
    category_changed = topic_changes.key?(:category_id)
    revised =
      revisor.revise!(
        editor,
        revision_changes,
        revision_options(params:, post:, guardian:, editor:, options:),
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

  def revision_options(params:, post:, guardian:, editor:, options:)
    attributes = params.changes
    revision_options = { keep_existing_draft: attributes[:keep_existing_draft].to_s == "true" }
    revision_options[:validate_post] = false if options.topic_revision

    # We don't need to validate edits to small action posts by staff
    revision_options[:skip_validations] = true if post.post_type == Post.types[:small_action] &&
      editor.staff?

    if attributes.key?(:bypass_bump) && guardian.can_update_bumped_at?
      revision_options[:bypass_bump] = ActiveModel::Type::Boolean.new.cast(attributes[:bypass_bump])
    end

    revision_options
  end
end
