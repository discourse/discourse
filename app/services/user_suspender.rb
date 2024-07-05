# frozen_string_literal: true

class UserSuspender
  attr_reader :user_history

  def initialize(user, suspended_till:, reason:, by_user:, message: nil, post_id: nil)
    @user = user
    @suspended_till = suspended_till
    @reason = reason
    @by_user = by_user
    @message = message
    @post_id = post_id
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
        )
    end
    @user.logged_out

    if @message.present?
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
