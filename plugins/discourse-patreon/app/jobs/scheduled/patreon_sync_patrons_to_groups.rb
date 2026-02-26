# frozen_string_literal: true

module Jobs
  class PatreonSyncPatronsToGroups < ::Jobs::Scheduled
    every 6.hours
    sidekiq_options retry: false

    def execute(_args)
      unless SiteSetting.patreon_enabled && SiteSetting.patreon_creator_access_token.present? &&
               SiteSetting.patreon_creator_refresh_token.present?
        return
      end

      Patreon::Patron.update!
      PatreonSyncLog.create!(synced_at: Time.zone.now)

      # Keep only the most recent sync logs
      PatreonSyncLog.order(synced_at: :desc).offset(100).delete_all
    end
  end
end
