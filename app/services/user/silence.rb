# frozen_string_literal: true

class User::Silence
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :reason, :string
    attribute :message, :string
    attribute :silenced_till, :datetime
    attribute :other_user_ids, :array
    attribute :post_id, :integer
    attribute :post_action, :string
    attribute :post_edit, :string
    attribute :reviewable_id, :integer
    attribute :reviewable_outcome_id, :integer

    validates :user_id, presence: true
    validates :reason, presence: true, length: { maximum: 300 }
    validates :silenced_till, presence: true
    validates :other_user_ids, length: { maximum: User::MAX_SIMILAR_USERS }
    validates :post_action,
              inclusion: {
                in: %w[delete delete_replies edit none],
              },
              allow_blank: true
  end

  model :user
  policy :not_silenced_already, class_name: User::Policy::NotAlreadySilenced
  model :users
  policy :can_silence_all_users
  step :silence
  model :post, optional: true
  step :perform_post_action
  only_if :reviewable_outcome_present? do
    step :record_reviewable_restrictions
  end

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def fetch_users(user:, params:)
    [user, *User.where(id: params.other_user_ids.to_a.uniq).to_a]
  end

  def can_silence_all_users(guardian:, users:)
    users.all? { guardian.can_silence_user?(it) }
  end

  def silence(guardian:, users:, params:)
    context[:full_reason] = User::Action::SilenceAll.call(users:, actor: guardian.user, params:)
  end

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end

  def perform_post_action(guardian:, post:, params:)
    User::Action::TriggerPostAction.call(guardian:, post:, params:)
  end

  def reviewable_outcome_present?(user:, params:)
    params.reviewable_outcome_id.present? && user.silenced?
  end

  def record_reviewable_restrictions(user:, post:, params:)
    restrictions = ["account_restriction_suspension"]
    if post && params.post_action.in?(%w[delete delete_replies]) &&
         Post.with_deleted.find_by(id: post.id)&.trashed?
      restrictions << "visibility_restriction_removal"
    end

    result =
      ReviewableOutcome::AddRestrictions.call(
        params: {
          outcome_id: params.reviewable_outcome_id,
          reviewable_id: params.reviewable_id,
          user_id: user.id,
          restriction_type: restrictions,
        },
      )
    unless result.success?
      raise Discourse::InvalidParameters.new("reviewable outcome could not be updated")
    end
  end
end
