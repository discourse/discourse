# frozen_string_literal: true

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
  end

  transaction do
    model :topic
    policy :can_edit_topic_record
    model :post
    model :changes
    policy :can_edit_post
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
  end

  private

  def fetch_post(params:, guardian:)
    posts = guardian.is_staff? ? Post.with_deleted : Post.all
    if params.topic_id
      posts.where(topic_id: params.topic_id).order(:post_number).lock.first
    else
      posts.lock.find_by(id: params.post_id)
    end
  end

  def fetch_topic(params:, guardian:)
    topics = guardian.is_staff? ? Topic.with_deleted : Topic.all
    posts = guardian.is_staff? ? Post.with_deleted : Post.all
    topic_id = params.topic_id || posts.where(id: params.post_id).pick(:topic_id)
    topics.lock.find_by(id: topic_id)
  end

  def can_edit_topic_record(params:, topic:, guardian:)
    params.topic_id.blank? || guardian.can_edit?(topic)
  end

  def fetch_changes(params:, post:, topic:, guardian:)
    Post::EditChanges.new(
      post:,
      topic:,
      guardian:,
      attributes: params.changes,
      topic_only: params.topic_id.present?,
    )
  end

  def can_edit_post(params:, post:, guardian:)
    params.topic_id.present? || guardian.can_edit?(post)
  end

  def can_edit_topic(params:, changes:, topic:, guardian:)
    return true if params.topic_id.present?
    changes.topic_attributes.except(:tags).empty? || guardian.can_edit_topic?(topic)
  end

  def can_edit_tags(changes:, topic:, guardian:)
    !changes.topic_attributes.key?(:tags) || guardian.can_edit_tags?(topic)
  end

  def check_edit_conflicts(changes:, post:, topic:)
    originals = changes.attributes
    conflict = originals[:original_text].present? && originals[:original_text] != post.raw
    if post.is_first_post?
      conflict ||= originals[:original_title].present? && originals[:original_title] != topic.title
      tag_ids = originals[:original_tags]&.map { |tag| tag.is_a?(String) ? 0 : tag[:id].to_i }&.sort
      conflict ||= tag_ids.present? && tag_ids != topic.tags.pluck(:id).sort
    end
    fail!(I18n.t("edit_conflict")) if conflict
  end

  def category_changed?(changes:)
    changes.category_changed?
  end

  def shared_draft?(topic:)
    topic.shared_draft.present?
  end

  def revision_requested?(changes:)
    changes.revision_requested?
  end

  def validate_category_change(changes:, topic:, guardian:)
    result =
      TopicCategoryChangeValidator.call(
        topic:,
        category_id: changes.topic_attributes[:category_id],
        guardian:,
        tag_names: changes.resolved_tag_names,
        tags_changed: changes.topic_attributes.key?(:tags),
      )
    return if result.success?

    topic.errors.add(:base, result.error)
    context[:status] = result.status
    fail!(result.error)
  end

  def update_shared_draft_destination(changes:, topic:)
    topic.shared_draft.update!(category_id: changes.topic_attributes[:category_id])
  end

  def revise_post(changes:, post:, topic:, guardian:)
    post.image_sizes = changes.attributes[:image_sizes] if changes.attributes[:image_sizes].present?
    revisor = PostRevisor.new(post, topic)
    topic_edit_requested = changes.topic_edit_requested?
    revised = revisor.revise!(guardian.user, changes.revision_attributes, changes.revision_options)
    context[:category_changed] = revisor.category_changed

    if topic.errors.present?
      errors =
        TopicCategoryChangeValidator.safe_revision_errors(
          topic:,
          guardian:,
          category_changed: changes.category_changed?,
        )
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
end
