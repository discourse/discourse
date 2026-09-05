# frozen_string_literal: true

require Rails.root.join("db/migrate/20260902075239_remove_browser_pageview_event_site_settings.rb")

RSpec.describe RemoveBrowserPageviewEventSiteSettings do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "removes the obsolete settings and preserves unrelated settings" do
    data_type = SiteSettings::TypeSupervisor.types[:bool]
    SiteSetting.create!(name: "persist_browser_pageview_events", value: "f", data_type:)
    SiteSetting.create!(name: "trigger_browser_pageview_events", value: "t", data_type:)
    unrelated_setting = SiteSetting.create!(name: "unrelated_setting", value: "t", data_type:)

    described_class.new.up

    expect(
      SiteSetting.where(name: %w[persist_browser_pageview_events trigger_browser_pageview_events]),
    ).to be_empty
    expect(unrelated_setting.reload.value).to eq("t")
  end
end
