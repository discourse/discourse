module Jobs
  class DisableBootstrapMode < Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.bootstrap_mode_enabled
      total_users = User.where.not(id: Discourse::SYSTEM_USER_ID).count

      if SiteSetting.bootstrap_mode_min_users == 0 || total_users > SiteSetting.bootstrap_mode_min_users
        update_site_setting('default_trust_level', TrustLevel[0])
        update_site_setting('default_email_digest_frequency', 10080)
        update_site_setting('bootstrap_mode_enabled', false)
      end
    end

    def update_site_setting(id, value)
      prev_value = SiteSetting.send(id)
      SiteSetting.set(id, value)
      StaffActionLogger.new(Discourse.system_user).log_site_setting_change(id, prev_value, value) if SiteSetting.has_setting?(id)
    end
  end
end
