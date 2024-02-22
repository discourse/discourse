# frozen_string_literal: true

module Jobs
  class CleanUpUserApiKeysMaxLife < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      if SiteSetting.revoke_user_api_keys_maxlife_days > 0
        revoke_days_ago = SiteSetting.revoke_user_api_keys_maxlife_days.days.ago

        UserApiKey
          .active
          .where("created_at < ?", revoke_days_ago)
          .update_all(revoked_at: Time.zone.now)
      end
    end
  end
end
