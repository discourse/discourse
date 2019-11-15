# frozen_string_literal: true

module Jobs
  class DisableBootstrapMode < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.bootstrap_mode_enabled
      total_users = User.human_users.count

      if SiteSetting.bootstrap_mode_min_users == 0 || total_users > SiteSetting.bootstrap_mode_min_users
        if SiteSetting.default_trust_level == TrustLevel[1]
          SiteSetting.set_and_log('default_trust_level', TrustLevel[0])
        end

        if SiteSetting.default_email_digest_frequency == 1440
          SiteSetting.set_and_log('default_email_digest_frequency', 10080)
        end

        SiteSetting.set_and_log('bootstrap_mode_enabled', false)
      end
    end
  end
end
