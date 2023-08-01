# frozen_string_literal: true

module Jobs
  class DisableBootstrapMode < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return if !SiteSetting.bootstrap_mode_enabled

      if SiteSetting.bootstrap_mode_min_users != 0 &&
           User.human_users.count <= SiteSetting.bootstrap_mode_min_users
        return
      end

      if SiteSetting.default_trust_level == TrustLevel[1]
        SiteSetting.set_and_log("default_trust_level", TrustLevel[0])
      end

      if SiteSetting.default_email_digest_frequency == 1440
        SiteSetting.set_and_log("default_email_digest_frequency", 10_080)
      end

      SiteSetting.set_and_log("bootstrap_mode_enabled", false)
    end
  end
end
