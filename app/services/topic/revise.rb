# frozen_string_literal: true

# Saves topic edits and shared draft destinations together, preserving revision history.
class Topic::Revise
  include Service::Base

  # @!method self.call(guardian:, editor:, params:)
  #   @param guardian [Guardian] permissions of the person editing
  #   @param editor [User] person credited with the revision
  #   @param params [Hash] topic revision inputs
  #   @option params [Integer] :topic_id topic to edit
  #   @option params [Hash, ActionController::Parameters] :changes ({}) topic fields and
  #     conflict checks accepted by {Post::Revise.call}. Post body fields are ignored.
  #     For shared drafts, category_id changes the publication destination.
  #   @return [Service::Base::Context] result when called without an outcome block
  #   @yield Register handlers through {Service::Runner}:
  #     * on_success: exposes topic and post.
  #     * on_failed_contract: missing topic_id or malformed changes.
  #     * on_model_not_found(:topic) or (:post): content was not found.
  #     * on_failed_policy(:can_edit_topic) or (:can_edit_tags): permission denied.
  #     * on_failed_step(:check_edit_conflicts): the original title or tags changed.
  #     * on_failed_step(:validate_destination): topic.errors and status describe rejection.
  #     * on_failed_step(:revise_post): post.errors or topic.errors describe revision failure.
  #     * on_failure: fallback for an outcome without a more specific handler.
  #   @example Change a shared draft destination and title together
  #     Topic::Revise.call(
  #       guardian: editor.guardian,
  #       editor:,
  #       params: { topic_id: topic.id, changes: { category_id: category.id, title: "New title" } },
  #     ) do
  #       on_success { |topic:| render_serialized(topic, BasicTopicSerializer) }
  #       on_failure { |topic:| render_json_error(topic) }
  #     end

  params(base_class: Post::Revise::RevisionContract) do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic
  policy :can_edit_topic
  model :post
  step :prepare_changes
  policy :can_edit_tags
  step :check_edit_conflicts

  only_if :destination_changed? do
    step :validate_destination
  end

  transaction do
    only_if :destination_changed? do
      step :update_shared_draft_destination
    end

    only_if :revision_requested? do
      step :revise_post
    end
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_edit_topic(topic:, guardian:)
    guardian.can_edit?(topic)
  end

  def fetch_post(topic:, guardian:)
    posts = guardian.is_staff? ? topic.posts.with_deleted : topic.posts

    posts.order(:post_number).first
  end

  def prepare_changes(params:, topic:)
    changes = params.changes.slice(*PostRevisor.tracked_topic_fields.keys)
    changes.delete(:title) if changes[:title] == topic.title
    changes.delete(:category_id) if changes[:category_id].to_i == topic.category_id.to_i

    if changes.key?(:tags) &&
         (!Tag.include_tags? || PostRevisor.tag_change_noop?(topic, changes[:tags]))
      changes.delete(:tags)
    end

    context[:destination_changes] = topic.shared_draft ? changes.extract!(:category_id) : {}
    context[:revision_changes] = changes
  end

  def can_edit_tags(revision_changes:, topic:, guardian:)
    !revision_changes.key?(:tags) || guardian.can_edit_tags?(topic)
  end

  def check_edit_conflicts(params:, topic:)
    originals = params.changes
    conflict = originals[:original_title].present? && originals[:original_title] != topic.title
    tag_ids = originals[:original_tags]&.map { |tag| tag.is_a?(String) ? 0 : tag[:id].to_i }&.sort
    conflict ||= tag_ids.present? && tag_ids != topic.tags.pluck(:id).sort

    fail!(I18n.t("edit_conflict")) if conflict
  end

  def destination_changed?(destination_changes:)
    destination_changes.present?
  end

  def validate_destination(topic:, guardian:, destination_changes:)
    result =
      TopicCategoryChangeValidator.call(
        topic:,
        guardian:,
        category_id: destination_changes[:category_id],
        tag_names: nil,
        tags_changed: false,
      )
    return if result.success?

    topic.errors.add(:base, result.error)
    context[:status] = result.status
    fail!(result.error)
  end

  def update_shared_draft_destination(topic:, destination_changes:)
    topic.shared_draft.update!(destination_changes)
  end

  def revision_requested?(revision_changes:)
    revision_changes.present?
  end

  def revise_post(params:, revision_changes:, post:, guardian:, editor:)
    result =
      Post::Revise.call(
        guardian:,
        editor:,
        params: {
          post_id: post.id,
          changes: revision_changes.merge(params.changes.slice(:keep_existing_draft)),
        },
        options: {
          topic_revision: true,
        },
      )
    context[:post] = result[:post]
    context[:topic] = result[:topic]
    context[:status] = result[:status] if result[:status]

    if result.failure?
      fail!(result[:post].errors.full_messages + result[:topic].errors.full_messages)
    end
  end
end
