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
          status: :experimental,
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

  it "can enable and disable an upcoming change using the dropdown" do
    upcoming_changes_page.visit

    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_disabled
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("everyone")
    expect(upcoming_changes_page).to have_enabled_for_success_toast("everyone")
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled
    expect(SiteSetting.enable_upload_debug_mode).to be_truthy

    # Revisit the page to skip the rate limit
    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("no_one")
    expect(upcoming_changes_page).to have_disabled_success_toast
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_disabled

    expect(SiteSetting.enable_upload_debug_mode).to be_falsey
  end

  it "tests different enabled_for options behavior" do
    upcoming_changes_page.visit

    # Add a group to test clearing behavior
    SiteSetting.enable_upload_debug_mode = true
    Fabricate(
      :site_setting_group,
      name: "enable_upload_debug_mode",
      group_ids: Group::AUTO_GROUPS[:trust_level_4].to_s,
    )

    # Refresh after setting up the group
    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_groups(
      "trust_level_4",
    )
    expect(UpcomingChanges.has_groups?(:enable_upload_debug_mode)).to be_truthy

    # Test 'no_one' option - should disable the change and clear groups
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("no_one")
    expect(upcoming_changes_page).to have_disabled_success_toast
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_disabled

    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_no_group_selector
    expect(SiteSetting.enable_upload_debug_mode).to be_falsey
    expect(UpcomingChanges.has_groups?(:enable_upload_debug_mode)).to be_falsey

    # Test 'everyone' option - should enable the change and clear groups
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("everyone")
    expect(upcoming_changes_page).to have_enabled_for_success_toast("everyone")
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled

    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_no_group_selector
    expect(SiteSetting.enable_upload_debug_mode).to be_truthy

    # Test 'staff' option - should enable the change and set staff group
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("staff")
    expect(upcoming_changes_page).to have_enabled_for_success_toast("staff")
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled

    upcoming_changes_page.visit
    expect(UpcomingChanges.has_groups?(:enable_upload_debug_mode)).to be_truthy
    expect(SiteSetting.enable_upload_debug_mode).to be_truthy

    # Test 'groups' option - should not change enabled state until groups are selected and saved
    upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("groups")
    upcoming_changes_page.change_item(:enable_upload_debug_mode).add_group("trust_level_4")
    upcoming_changes_page.change_item(:enable_upload_debug_mode).save_groups
    expect(upcoming_changes_page).to have_enabled_for_success_toast(
      "specific_groups_with_group_names",
      translation_args: {
        groupNames: "staff, trust_level_4",
        count: 2,
      },
    )

    upcoming_changes_page.visit
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to have_groups(
      "staff",
      "trust_level_4",
    )
    expect(upcoming_changes_page.change_item(:enable_upload_debug_mode)).to be_enabled
    expect(UpcomingChanges.has_groups?(:enable_upload_debug_mode)).to be_truthy
    expect(SiteSetting.enable_upload_debug_mode).to be_truthy
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

    # Filter by impact role
    upcoming_changes_page.filter_controls.select_dropdown_option(
      "Developers",
      dropdown_id: "impactRole",
    )

    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.select_all_dropdown_option(dropdown_id: "impactRole")

    # Filter by enabled/disabled
    upcoming_changes_page.filter_controls.select_dropdown_option("Enabled", dropdown_id: "enabled")

    expect(upcoming_changes_page).to have_no_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.select_all_dropdown_option(dropdown_id: "enabled")
  end
end
