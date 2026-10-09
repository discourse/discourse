# frozen_string_literal: true

class User::Action::SuspendAll < Service::ActionBase
  option :users, []
  option :actor
  option :params
  option :raise_on_failure, default: -> { false }

  delegate :message, :post_id, :suspend_until, :reason, :reviewable_id, to: :params, private: true

  attr_reader :restrictions

  def call
    @restrictions = []
    suspended_users.first.try(:user_history).try(:details)
  end

  private

  def suspended_users
    users.map do |user|
      UserSuspender
        .new(
          user,
          suspended_till: suspend_until,
          reason: reason,
          by_user: actor,
          message: message,
          post_id: post_id,
          reviewable_id: reviewable_id,
        )
        .tap do |suspender|
          suspender.suspend
          @restrictions << Reviewable::Restriction.new(
            kind: :suspended,
            target: user,
            expires_at: user.suspended_till,
          )
        end
    rescue => err
      raise if raise_on_failure
      Discourse.warn_exception(err, message: "failed to suspend user with ID #{user.id}")
    end
  end
end
