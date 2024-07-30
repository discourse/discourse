# frozen_string_literal: true

describe "Admin Site Setting Search", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)

  before do
    SiteSetting.title = "Discourse"
    sign_in(admin)
  end

  it "clears the filter" do
    settings_page.visit
    settings_page.type_in_search("min personal message post length")
    expect(settings_page).to have_n_results(1)
    settings_page.clear_search
    expect(settings_page).to have_greater_than_n_results(1)
  end

  it "can show only overridden settings" do
    overridden_setting_count = SiteSetting.all_settings(only_overridden: true).length
    settings_page.visit
    settings_page.toggle_only_show_overridden
    assert_selector(".admin-detail .row.setting.overridden", count: overridden_setting_count)
    settings_page.toggle_only_show_overridden
    expect(settings_page).to have_greater_than_n_results(overridden_setting_count)
  end

  describe "when searching for keywords" do
    it "finds the associated site setting" do
      settings_page.visit
      settings_page.type_in_search("anonymous_posting_min_trust_level")
      expect(settings_page).to have_search_result("anonymous_posting_allowed_groups")
    end

    it "finds the associated site setting when many keywords" do
      settings_page.visit
      settings_page.type_in_search("deactivated")
      expect(settings_page).to have_search_result("clean_up_inactive_users_after_days")
      expect(settings_page).to have_search_result("purge_unactivated_users_grace_period_days")
    end

    it "can search for previous site setting without underscores" do
      settings_page.visit
      settings_page.type_in_search("anonymous posting min")
      expect(settings_page).to have_search_result("anonymous_posting_allowed_groups")
    end
  end
end
