# frozen_string_literal: true

module Jobs
  # A suspension ends through the job scheduled when it was applied. This one catches those whose job never
  # ran (applied before that job existed, or lost with Redis), so their end is still announced, once.
  class ExpireUnannouncedSuspensions < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      User
        .where("suspended_till < ? AND suspended_at IS NOT NULL", Time.zone.now)
        .where(<<~SQL, unsuspend: UserHistory.actions[:unsuspend_user])
          NOT EXISTS (
            SELECT 1
            FROM user_histories
            WHERE user_histories.target_user_id = users.id
              AND user_histories.action = :unsuspend
              AND user_histories.created_at >= users.suspended_till
          )
        SQL
        .find_each do |user|
          UserSuspender.expire(
            user,
            suspended_at: user.suspended_at,
            suspended_till: user.suspended_till,
          )
        end
    end
  end
end
