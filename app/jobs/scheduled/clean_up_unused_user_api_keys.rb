# frozen_string_literal: true

module Jobs
  class CleanUpUnusedUserApiKeys < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      if SiteSetting.revoke_user_api_keys_unused_days > 0
        revoke_days_ago = SiteSetting.revoke_user_api_keys_unused_days.days.ago

        UserApiKey
          .active
          .where("last_used_at < ?", revoke_days_ago)
          .update_all(revoked_at: Time.zone.now)
      end
    end
  end
end
