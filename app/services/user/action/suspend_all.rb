# frozen_string_literal: true

class User::Action::SuspendAll < Service::ActionBase
  option :users, []
  option :actor
  option :params

  delegate :message, :post_id, :suspend_until, :reason, :reviewable_id, to: :params, private: true

  def call
    suspended_users.first.try(:user_history).try(:details)
  end

  private

  def suspended_users
    users.map do |user|
      UserSuspender.new(
        user,
        suspended_till: suspend_until,
        reason: reason,
        by_user: actor,
        message: message,
        post_id: post_id,
        reviewable_id: reviewable_id,
        reviewable_outcome_id: user.id == params.user_id ? params.reviewable_outcome_id : nil,
      ).tap(&:suspend)
    rescue => err
      raise if params.reviewable_outcome_id.present? && user.id == params.user_id
      Discourse.warn_exception(err, message: "failed to suspend user with ID #{user.id}")
    end
  end
end
