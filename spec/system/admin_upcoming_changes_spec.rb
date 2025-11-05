# frozen_string_literal: true

describe "Admin upcoming changes", type: :system do
  fab!(:current_user, :admin)
  let(:upcoming_changes_page) { PageObjects::Pages::AdminUpcomingChanges.new }

  before do
    SiteSetting.enable_upcoming_changes = true

    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :pre_alpha,
          impact_type: "other",
          impact_role: "developers",
        },
        about_page_extra_groups_show_description: {
          impact: "feature,all_members",
          status: :stable,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    sign_in(current_user)
  end

  it "shows a list of upcoming changes and their metadata" do
    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:about_page_extra_groups_show_description)
    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)

    expect(
      upcoming_changes_page.change_item(:about_page_extra_groups_show_description),
    ).to have_status(:stable)
    expect(
      upcoming_changes_page.change_item(:about_page_extra_groups_show_description),
    ).to have_impact_role(:all_members)
  end

  # NOTE (martin): Skipped for now because it is flaky on CI, it will be something to do with the
  # sample plugin settings loaded in the SiteSetting model.
  xit "shows upcoming changes from plugins" do
    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:enable_experimental_sample_plugin_feature)
    expect(
      upcoming_changes_page.change_item(:enable_experimental_sample_plugin_feature),
    ).to have_plugin_name("Sample plugin")
  end

  it "can toggle an upcoming change on or off" do
    upcoming_changes_page.visit

    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_disabled
    upcoming_changes_page.change_item(:enable_upload_debug_mode).toggle
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.change_enabled"))
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled

    # Revisit the page to skip the 3s toggle rate limit
    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled
    upcoming_changes_page.change_item(:enable_upload_debug_mode).toggle
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.change_disabled"))
  end

  it "can add and remove groups for a change" do
    SiteSettingGroup.create!(
      name: "enable_upload_debug_mode",
      group_ids: Group::AUTO_GROUPS[:trust_level_4].to_s,
    )
    SiteSetting.refresh_site_setting_group_ids!
    SiteSetting.notify_changed!

    upcoming_changes_page.visit

    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_groups(
      "trust_level_4",
    )
    upcoming_changes_page.change_item(:enable_upload_debug_mode).add_group("staff")
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.groups_updated"))

    expect(
      SiteSettingGroup.find_by(name: "enable_upload_debug_mode").group_ids.split("|").map(&:to_i),
    ).to match_array([Group::AUTO_GROUPS[:trust_level_4], Group::AUTO_GROUPS[:staff]])
    expect(SiteSetting.site_setting_group_ids[:enable_upload_debug_mode]).to match_array(
      [Group::AUTO_GROUPS[:trust_level_4], Group::AUTO_GROUPS[:staff]],
    )

    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_groups(
      "trust_level_4",
      "staff",
    )

    upcoming_changes_page.change_item(:enable_upload_debug_mode).remove_group("trust_level_4")
    expect(page).to have_content(I18n.t("admin_js.admin.upcoming_changes.groups_updated"))

    expect(
      SiteSettingGroup.find_by(name: "enable_upload_debug_mode").group_ids.split("|").map(&:to_i),
    ).to match_array([Group::AUTO_GROUPS[:staff]])
    expect(SiteSetting.site_setting_group_ids[:enable_upload_debug_mode]).to match_array(
      [Group::AUTO_GROUPS[:staff]],
    )
  end

  it "can filter by name, description, plugin, status, impact type, or enabled/disabled" do
    upcoming_changes_page.visit

    # Filter by name
    upcoming_changes_page.filter_controls.type_in_search("upload debug")

    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.clear_search

    # Filter by plugin
    # NOTE (martin): Skipped for now because it is flaky on CI, it will be something to do with the
    # sample plugin settings loaded in the SiteSetting model.
    # upcoming_changes_page.filter_controls.type_in_search("sample plugin")

    # expect(upcoming_changes_page).to have_change(:enable_experimental_sample_plugin_feature)
    # expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    # upcoming_changes_page.filter_controls.clear_search

    upcoming_changes_page.filter_controls.toggle_dropdown_filters

    # Filter by status
    upcoming_changes_page.filter_controls.select_dropdown_option("Stable", dropdown_id: "status")

    expect(upcoming_changes_page).to have_no_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.select_all_dropdown_option(dropdown_id: "status")

    # Filter by impact type
    upcoming_changes_page.filter_controls.select_dropdown_option("Feature", dropdown_id: "type")

    expect(upcoming_changes_page).to have_no_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.select_all_dropdown_option(dropdown_id: "type")

    # Filter by enabled/disabled
    upcoming_changes_page.filter_controls.select_dropdown_option("Enabled", dropdown_id: "enabled")

    expect(upcoming_changes_page).to have_no_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.select_all_dropdown_option(dropdown_id: "enabled")
  end
end
