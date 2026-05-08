# frozen_string_literal: true

DiscourseEvent.on(:browser_pageview) do |payload|
  BrowserPageviewEvent.defer_record!(payload) if SiteSetting.site_traffic_data_layer_enabled
end

DiscourseEvent.on(:beacon_browser_pageview) do |payload|
  BrowserPageviewBeaconEvent.defer_record!(payload) if SiteSetting.site_traffic_data_layer_enabled
end

DiscourseEvent.on(:user_destroyed) do |user|
  Scheduler::Defer.later("Null site traffic pageview user") do
    BrowserPageviewEvent.null_user!(user.id)
    BrowserPageviewBeaconEvent.null_user!(user.id)
  end
end
