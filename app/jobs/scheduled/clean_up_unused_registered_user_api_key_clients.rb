# frozen_string_literal: true

module Jobs
  class CleanUpUnusedRegisteredUserApiKeyClients < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      if SiteSetting.unused_registered_user_api_key_clients_days > 0
        destroy_days_ago = SiteSetting.unused_registered_user_api_key_clients_days.days.ago

        clients =
          UserApiKeyClient
            .where("auth_redirect IS NOT NULL")
            .where(
              "id NOT IN (SELECT user_api_key_client_id FROM user_api_keys WHERE user_api_keys.last_used_at > ?)",
              destroy_days_ago,
            )
            .distinct
            .destroy_all
      end
    end
  end
end
