# frozen_string_literal: true

class User::Action::TriggerPostAction < Service::ActionBase
  option :guardian
  option :post
  option :params
  option :raise_on_failure, default: -> { false }

  delegate :post_action, :reviewable_id, to: :params, private: true
  delegate :user, to: :guardian, private: true

  def call
    return if post.blank? || post_action.blank? || %w[none delete_all].include?(post_action)
    send(post_action)
  rescue NoMethodError
    raise if raise_on_failure
  end

  private

  def delete
    guardian.ensure_can_delete_post_or_topic!(post) if raise_on_failure
    return unless guardian.can_delete_post_or_topic?(post)
    PostDestroyer.new(user, post, reviewable_id: reviewable_id).destroy
    raise Discourse::InvalidParameters.new(:post_action) if raise_on_failure && !post.trashed?
  end

  def delete_replies
    guardian.ensure_can_delete_post_or_topic!(post) if raise_on_failure
    return unless guardian.can_delete_post_or_topic?(post)
    PostDestroyer.delete_with_replies(user, post, reviewable_id)
  end

  def edit
    guardian.ensure_can_edit_post!(post) if raise_on_failure
    return unless guardian.can_edit_post?(post)
    # Take what the moderator edited in as gospel
    PostRevisor.new(post).revise!(
      user,
      { raw: params.post_edit },
      skip_validations: true,
      skip_revision: true,
    )
    if raise_on_failure
      raise ActiveRecord::RecordInvalid.new(post) if post.errors.present?
      raise ActiveRecord::RecordInvalid.new(post.topic) if post.topic.errors.present?
    end
  end
end
