# frozen_string_literal: true

class UserSuspender
  SUSPENSION_EXPIRY_CONTEXT = "suspension_expired"
  TIMESTAMP_PRECISION = 6

  attr_reader :user_history

  def self.expire(user, suspended_at:, suspended_till:)
    actor = Discourse.system_user

    user.with_lock(requires_new: true) do
      return if user.suspended_at != suspended_at || user.suspended_till != suspended_till
      return if user.suspended?

      context = expiry_context(suspended_at, suspended_till)
      return if user.user_histories.where(context: context).exists?

      StaffActionLogger.new(actor).log_user_unsuspend(user, context: context)
      DiscourseEvent.trigger(:user_unsuspended, user: user, by_user: actor)
    end
  end

  def self.unsuspend(user, by_user:)
    user.with_lock(requires_new: true) do
      return false if user.suspended_till.nil?
      # Keeps the dates of a suspension whose end was already logged and
      # announced, so its end isn't reported a second time.
      return false if !user.suspended? && expiry_announced?(user)

      user.update!(suspended_at: nil, suspended_till: nil)
      StaffActionLogger.new(by_user).log_user_unsuspend(user)

      DiscourseEvent.trigger(:user_unsuspended, user: user, by_user: by_user)
    end

    true
  end

  def self.expiry_context(suspended_at, suspended_till)
    [
      SUSPENSION_EXPIRY_CONTEXT,
      suspended_at.utc.iso8601(TIMESTAMP_PRECISION),
      suspended_till.utc.iso8601(TIMESTAMP_PRECISION),
    ].join(":")
  end
  private_class_method :expiry_context

  def self.expiry_announced?(user)
    return false if user.suspended_at.nil?

    user
      .user_histories
      .where(context: expiry_context(user.suspended_at, user.suspended_till))
      .exists?
  end
  private_class_method :expiry_announced?

  def initialize(
    user,
    suspended_till:,
    reason:,
    by_user:,
    message: nil,
    post_id: nil,
    reviewable_id: nil
  )
    @user = user
    @suspended_till = suspended_till
    @reason = reason
    @by_user = by_user
    @message = message
    @post_id = post_id
    @reviewable_id = reviewable_id
  end

  def suspend
    suspended_at = DateTime.now

    @user.suspended_till = @suspended_till
    @user.suspended_at = suspended_at

    @user.transaction do
      @user.save!

      @user_history =
        StaffActionLogger.new(@by_user).log_user_suspend(
          @user,
          @reason,
          message: @message,
          post_id: @post_id,
          reviewable_id: @reviewable_id,
        )
    end
    @user.log_out!

    Jobs.enqueue_at(
      @user.suspended_till,
      :user_suspension_expired,
      user_id: @user.id,
      suspended_at: @user.suspended_at.iso8601(TIMESTAMP_PRECISION),
      suspended_till: @user.suspended_till.iso8601(TIMESTAMP_PRECISION),
    )

    if @message.present? || SiteSetting.dsa_reporting_enabled
      Jobs.enqueue(
        Jobs::CriticalUserEmail,
        type: "account_suspended",
        user_id: @user.id,
        user_history_id: @user_history.id,
      )
    end

    DiscourseEvent.trigger(
      :user_suspended,
      user: @user,
      by_user: @by_user,
      reason: @reason,
      message: @message,
      user_history: @user_history,
      post_id: @post_id,
      suspended_till: @suspended_till,
      suspended_at: suspended_at,
    )
    nil
  end
end
