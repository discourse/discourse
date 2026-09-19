# frozen_string_literal: true

class User::Action::SuspendAndPublish < Service::ActionBase
  option :user
  option :position
  option :guardian
  option :total_size
  option :suspend_until
  option :reason
  option :message, default: proc { nil }

  def call
    data = { position:, username: user.username, total: total_size }
    ::MessageBus.publish("/bulk-user-suspend", data.merge(suspend_user!), user_ids: [actor.id])
  end

  private

  def actor
    guardian.user
  end

  def suspend_user!
    UserSuspender.new(
      user,
      suspended_till: suspend_until,
      reason:,
      by_user: actor,
      message:,
    ).suspend
    { success: true }
  rescue => err
    { failed: true, error: err.message }
  end
end
