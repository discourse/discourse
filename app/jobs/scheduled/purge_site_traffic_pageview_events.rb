# frozen_string_literal: true

module Jobs
  class PurgeSiteTrafficPageviewEvents < ::Jobs::Scheduled
    every 1.day

    def execute(_args = {})
      BrowserPageviewEvent.null_ip_addresses_older_than(ip_retention_cutoff)
      BrowserPageviewBeaconEvent.null_ip_addresses_older_than(ip_retention_cutoff)

      BrowserPageviewEvent.purge_older_than(event_retention_cutoff)
      BrowserPageviewBeaconEvent.purge_older_than(event_retention_cutoff)
    end

    private

    def ip_retention_cutoff
      SiteSetting.site_traffic_event_ip_retention_days.days.ago
    end

    def event_retention_cutoff
      SiteSetting.site_traffic_event_retention_days.days.ago
    end
  end
end
