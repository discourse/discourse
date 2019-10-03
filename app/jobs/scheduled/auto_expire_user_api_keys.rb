# frozen_string_literal: true

module Jobs

  class AutoExpireUserApiKeys < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      if SiteSetting.expire_user_api_keys_days > 0
        expire_user_api_keys_days = SiteSetting.expire_user_api_keys_days.days.ago

        UserApiKey.where("last_used_at < ?", expire_user_api_keys_days).update_all(revoked_at: Time.zone.now)
      end
    end
  end

end
