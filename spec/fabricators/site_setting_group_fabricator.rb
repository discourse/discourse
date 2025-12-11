# frozen_string_literal: true

Fabricator(:site_setting_group) do
  after_create do |site_setting_group|
    SiteSetting.refresh_site_setting_group_ids!
    SiteSetting.notify_changed!
  end
end
