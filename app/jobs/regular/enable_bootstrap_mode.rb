module Jobs
  class EnableBootstrapMode < Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      return if SiteSetting.bootstrap_mode_enabled

      user = User.find_by(id: args[:user_id])
      return unless user.is_singular_admin?

      # let's enable bootstrap mode settings
      update_site_setting('default_trust_level', TrustLevel[1])
      update_site_setting('default_email_digest_frequency', 1440)
      update_site_setting('bootstrap_mode_enabled', true)
    end

    def update_site_setting(id, value)
      prev_value = SiteSetting.send(id)
      SiteSetting.set(id, value)
      StaffActionLogger.new(Discourse.system_user).log_site_setting_change(id, prev_value, value) if SiteSetting.has_setting?(id)
    end
  end
end
