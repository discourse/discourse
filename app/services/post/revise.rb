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
    model :post
    model :topic
    model :changes
    policy :can_edit_post
    policy :can_edit_topic
    policy :can_edit_tags
    step :check_edit_conflicts
    step :validate_category_change
    step :update_shared_draft_destination
    step :revise_post
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

  def fetch_topic(post:, guardian:)
    topics = guardian.is_staff? ? Topic.with_deleted : Topic.all
    topics.lock.find_by(id: post.topic_id)
  end

  def fetch_changes(params:, post:, topic:, guardian:)
    Post::EditChanges.new(post:, topic:, guardian:, attributes: params.changes, topic_only: params.topic_id.present?)
  end

  def can_edit_post(params:, post:, guardian:)
    params.topic_id.present? || guardian.can_edit?(post)
  end

  def can_edit_topic(params:, changes:, topic:, guardian:)
    return guardian.can_edit?(topic) if params.topic_id.present?
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
      tag_ids = originals[:original_tags]&.map { |tag| tag[:id].to_i }&.sort
      conflict ||= tag_ids.present? && tag_ids != topic.tags.pluck(:id).sort
    end
    fail! if conflict
  end

  def validate_category_change(changes:, topic:, guardian:)
    return unless changes.category_changed?

    result = TopicCategoryChangeValidator.call(
      topic:,
      category_id: changes.topic_attributes[:category_id],
      guardian:,
      tag_names: changes.resolved_tag_names,
      tags_changed: changes.topic_attributes.key?(:tags),
    )
    return if result.success?

    topic.errors.add(:base, result.error)
    fail!(status: result.status)
  end

  def update_shared_draft_destination(changes:, topic:)
    return unless changes.category_changed? && topic.shared_draft
    topic.shared_draft.update!(category_id: changes.topic_attributes[:category_id])
  end

  def revise_post(changes:, post:, topic:, guardian:)
    post.image_sizes = changes.attributes[:image_sizes] if changes.attributes[:image_sizes].present?
    revisor = PostRevisor.new(post, topic)
    revisor.revise!(guardian.user, changes.revision_attributes, changes.revision_options)
    context[:category_changed] = revisor.category_changed

    if topic.errors.present?
      errors = TopicCategoryChangeValidator.safe_revision_errors(topic:, guardian:, category_changed: changes.category_changed?)
      topic.errors.clear
      errors.each { |error| topic.errors.add(:base, error) }
    end
    if revisor.successfully_saved_post_and_topic == false && post.errors.empty? && topic.errors.empty?
      topic.errors.add(:base, :unable_to_update)
    end
    fail! if post.errors.present? || topic.errors.present?
  end
end
