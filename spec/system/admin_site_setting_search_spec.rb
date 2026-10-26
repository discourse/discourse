# frozen_string_literal: true

describe "Admin Site Setting Search" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  fab!(:admin)

  before do
    SiteSetting.title = "Discourse"
    sign_in(admin)
  end

  it "clears text, toggles overridden settings and finds shared keywords" do
    overridden_setting_count = SiteSetting.all_settings(only_overridden: true).length
    settings_page.visit
    settings_page.type_in_search("min personal message post length")
    expect(settings_page).to have_n_results(1)
    settings_page.clear_search
    expect(settings_page).to have_greater_than_n_results(1)

    settings_page.toggle_only_show_overridden
    assert_selector(".admin-detail .row.setting.overridden", count: overridden_setting_count)
    settings_page.toggle_only_show_overridden
    expect(settings_page).to have_greater_than_n_results(overridden_setting_count)

    settings_page.type_in_search("deactivated")

    aggregate_failures "find both settings with the shared keyword" do
      expect(settings_page).to have_search_result("clean_up_inactive_users_after_days")
      expect(settings_page).to have_search_result("purge_unactivated_users_grace_period_days")
    end

    settings_page.clear_search
    expect(settings_page).to have_greater_than_n_results(overridden_setting_count)
  end

  describe "when searching for keywords" do
    it "finds the replacement setting using deprecated names with underscores or spaces" do
      stub_deprecated_settings!(override: false) do
        settings_page.visit
        settings_page.type_in_search("old_one")
        expect(settings_page).to have_search_result("new_one")

        settings_page.clear_search
        settings_page.type_in_search("old one")
        expect(settings_page).to have_search_result("new_one")
      end
    end
  end
end
