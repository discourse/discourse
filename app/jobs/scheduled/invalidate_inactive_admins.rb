# frozen_string_literal: true

module Jobs

  class InvalidateInactiveAdmins < ::Jobs::Scheduled
    every 1.day

    def execute(_)
      return if SiteSetting.invalidate_inactive_admin_email_after_days == 0

      timestamp = SiteSetting.invalidate_inactive_admin_email_after_days.days.ago

      User.human_users
        .where(admin: true)
        .where(active: true)
        .where('last_seen_at < ?', timestamp)
        .where("NOT EXISTS ( SELECT 1 from api_keys WHERE api_keys.user_id = users.id AND COALESCE(last_used_at, updated_at) > ? )", timestamp)
        .where("NOT EXISTS ( SELECT 1 from posts WHERE posts.user_id = users.id AND created_at > ?)", timestamp)
        .each do |user|

        User.transaction do
          user.deactivate(Discourse.system_user)
          user.email_tokens.update_all(confirmed: false, expired: true)

          reason = I18n.t("user.deactivated_by_inactivity", count: SiteSetting.invalidate_inactive_admin_email_after_days)
          StaffActionLogger.new(Discourse.system_user).log_user_deactivate(user, reason)

          Discourse.authenticators.each do |authenticator|
            if authenticator.can_revoke? && authenticator.description_for_user(user).present?
              authenticator.revoke(user)
            end
          end
        end
      end
    end
  end

end
