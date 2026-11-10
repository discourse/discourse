# frozen_string_literal: true

class UserDeactivator
  class PendingReview < StandardError
  end

  def self.deactivate(guardian, user, context: {}, allow_deletion: false)
    guardian.ensure_can_deactivate!(user)
    User.transaction do
      user.lock!
      guardian.ensure_can_deactivate!(user)
      raise PendingReview if !allow_deletion && ReviewableUser.pending.exists?(target: user)
      user.deactivate(guardian.user)
      raise PendingReview if !allow_deletion && !User.exists?(user.id)
      StaffActionLogger.new(guardian.user).log_user_deactivate(
        user,
        I18n.t("user.deactivated_by_staff"),
        context,
      )
    end
  end
end
