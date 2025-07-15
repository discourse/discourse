# frozen_string_literal: true

module ::Jobs
  class PatreonSyncPatronsToGroups < ::Jobs::Scheduled
    every 6.hours
    sidekiq_options retry: false

    def execute(args)
      unless SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token &&
               SiteSetting.patreon_creator_refresh_token
        return
      end

      ::Patreon::Patron.update!
      ::Patreon.set("last_sync", at: Time.now)
    end
  end
end
