# frozen_string_literal: true

class SuspendUser
  include Service::Base

  contract

  step :set_users

  policy :can_suspend
  policy :not_suspended_already

  step :suspend
  step :perform_post_action

  class Contract
    attribute :reason, :string
    attribute :message, :string
    attribute :suspend_until, :string
    attribute :other_user_ids, :array
    attribute :post_id, :string
    attribute :post_action, :string
    attribute :post_edit, :string

    validates :reason, presence: true, length: { maximum: 300 }
    validates :suspend_until, presence: true
    validates :other_user_ids, length: { maximum: User::MAX_SIMILAR_USERS }
  end

  private

  def set_users(user:)
    list = [user]

    if context.other_user_ids.present?
      list.concat(User.where(id: context.other_user_ids).to_a)
      list.uniq!
    end

    context.users = list
  end

  def can_suspend(guardian:, users:)
    users.all? { |user| guardian.can_suspend?(user) }
  end

  def not_suspended_already(user:)
    !user.suspended?
  end

  def suspend(guardian:, users:, suspend_until:, reason:)
    users.each do |user|
      suspender =
        UserSuspender.new(
          user,
          suspended_till: suspend_until,
          reason: reason,
          by_user: guardian.user,
          message: context.message,
          post_id: context.post_id,
        )
      suspender.suspend
      context.user_history = suspender.user_history
    rescue => err
      Discourse.warn_exception(err, message: "failed to suspend user with ID #{user.id}")
    end
  end

  def perform_post_action(guardian:)
    Action::SuspendSilencePostAction.call(guardian:, context: context)
  end
end
