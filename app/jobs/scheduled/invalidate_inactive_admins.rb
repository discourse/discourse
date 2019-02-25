module Jobs

  class InvalidateInactiveAdmins < Jobs::Scheduled
    every 1.day

    def execute(_)
      return if SiteSetting.invalidate_inactive_admin_email_after_days == 0

      User.human_users
        .where(admin: true)
        .where(active: true)
        .where('last_seen_at < ?', SiteSetting.invalidate_inactive_admin_email_after_days.days.ago)
        .each do |user|

        User.transaction do
          user.deactivate
          user.email_tokens.update_all(confirmed: false, expired: true)

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
