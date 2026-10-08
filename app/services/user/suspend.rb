# frozen_string_literal: true

class User::Suspend
  include Service::Base

  params do
    attribute :user_id, :integer
    attribute :reason, :string
    attribute :message, :string
    attribute :suspend_until, :datetime
    attribute :other_user_ids, :array
    attribute :post_id, :integer
    attribute :post_action, :string
    attribute :post_edit, :string
    attribute :reviewable_id, :integer

    validates :user_id, presence: true
    validates :reason, presence: true, length: { maximum: 300 }
    validates :suspend_until, presence: true
    validates :other_user_ids, length: { maximum: User::MAX_SIMILAR_USERS }
    validates :post_action,
              inclusion: {
                in: %w[delete delete_replies delete_all edit none],
              },
              allow_blank: true
  end

  model :user
  policy :not_suspended_already, class_name: User::Policy::NotAlreadySuspended
  model :users
  policy :can_suspend_all_users
  model :post, optional: true
  step :apply_penalty

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def fetch_users(user:, params:)
    [user, *User.where(id: params.other_user_ids.to_a.uniq).to_a]
  end

  def can_suspend_all_users(guardian:, users:)
    users.all? { guardian.can_suspend?(it) }
  end

  def apply_penalty(guardian:, users:, user:, post:, params:)
    DsaModeration.capture_penalty(
      reviewable_id: params.reviewable_id,
      actor: guardian.user,
      user: user,
      action_name: "suspend_user",
    ) do
      context[:full_reason] = User::Action::SuspendAll.call(users:, actor: guardian.user, params:)
      User::Action::TriggerPostAction.call(guardian:, post:, params:)
    end
  end

  def fetch_post(params:)
    Post.find_by(id: params.post_id)
  end
end
