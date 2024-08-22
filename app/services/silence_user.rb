# frozen_string_literal: true

class SilenceUser
  include Service::Base

  contract

  step :set_users

  policy :can_silence
  policy :not_silenced_already

  step :silence
  step :perform_post_action

  class Contract
    attribute :reason, :string
    attribute :message, :string
    attribute :silenced_till, :string
    attribute :other_user_ids, :array
    attribute :post_id, :string
    attribute :post_action, :string
    attribute :post_edit, :string

    validates :reason, presence: true, length: { maximum: 300 }
    validates :silenced_till, presence: true
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

  def can_silence(guardian:, users:)
    users.all? { |user| guardian.can_silence_user?(user) }
  end

  def not_silenced_already(user:)
    !user.silenced?
  end

  def silence(guardian:, users:, silenced_till:, reason:)
    users.each do |user|
      silencer =
        UserSilencer.new(
          user,
          guardian.user,
          silenced_till: silenced_till,
          reason: reason,
          message_body: context.message,
          keep_posts: true,
          post_id: context.post_id,
        )

      if silencer.silence
        user_history = silencer.user_history
        Jobs.enqueue(
          :critical_user_email,
          type: "account_silenced",
          user_id: user.id,
          user_history_id: user_history.id,
        )
        context.user_history = user_history
      end
    end
  end

  def perform_post_action(guardian:)
    Action::SuspendSilencePostAction.call(guardian:, context: context)
  end
end
