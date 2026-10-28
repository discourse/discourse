# frozen_string_literal: true

describe "Admin upcoming changes" do
  fab!(:current_user, :admin)
  let(:upcoming_changes_page) { PageObjects::Pages::AdminUpcomingChanges.new }

  before do
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

    SiteSetting.about_page_extra_groups_show_description = false
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

  it "does not show conceptual upcoming changes" do
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
          status: :conceptual,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)
  end

  it "shows the permanent soon notice for stable changes unless permanent_warning is false" do
    mock_upcoming_change_metadata(
      {
        about_page_extra_groups_show_description: {
          impact: "feature,all_members",
          status: :stable,
          impact_type: "feature",
          impact_role: "all_members",
        },
        enable_upload_debug_mode: {
          impact: "site_setting_default,all_members",
          status: :stable,
          impact_type: "site_setting_default",
          impact_role: "all_members",
          permanent_warning: false,
        },
      },
    )

    upcoming_changes_page.visit

    expect(
      upcoming_changes_page.change_item(:about_page_extra_groups_show_description),
    ).to have_permanent_soon_notice
    expect(
      upcoming_changes_page.change_item(:enable_upload_debug_mode),
    ).to have_no_permanent_soon_notice
  end

  describe "when the change depends on other settings" do
    before do
      mock_upcoming_change_metadata(
        {
          set_locale_from_cookie: {
            impact: "feature,all_members",
            status: :experimental,
            impact_type: "feature",
            impact_role: "all_members",
          },
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
    end

    it "shows a warning notice with links when the dependencies are not met" do
      SiteSetting.allow_user_locale = false
      upcoming_changes_page.visit

      change_item = upcoming_changes_page.change_item(:set_locale_from_cookie)
      expect(change_item).to have_depends_on_notice(
        "This change requires Allow user locale to be enabled.",
      )
      expect(change_item.find_item(:set_locale_from_cookie)).to have_link(
        "Allow user locale",
        href: "/admin/site_settings/category/all_results?filter=allow_user_locale",
      )
      expect(
        upcoming_changes_page.change_item(:enable_upload_debug_mode),
      ).to have_no_depends_on_notice
    end

    it "does not show the notice when the dependencies are met" do
      SiteSetting.allow_user_locale = true
      upcoming_changes_page.visit

      expect(
        upcoming_changes_page.change_item(:set_locale_from_cookie),
      ).to have_no_depends_on_notice
    end
  end

  it "does not show permanent upcoming changes" do
    mock_upcoming_change_metadata(
      {
        allow_uppercase_posts: {
          impact: "feature,all_members",
          status: :permanent,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_no_change(:allow_uppercase_posts)
  end

  it "shows upcoming changes from plugins" do
    upcoming_changes_page.visit
    expect(upcoming_changes_page).to have_change(:enable_experimental_sample_plugin_feature)
    expect(
      upcoming_changes_page.change_item(:enable_experimental_sample_plugin_feature),
    ).to have_plugin_name("Sample plugin")
  end

  it "lets an admin enable and disable an upcoming change with the toggle" do
    upcoming_changes_page.visit
    item = upcoming_changes_page.change_item(:enable_upload_debug_mode)

    expect(item).to be_disabled
    item.toggle
    expect(upcoming_changes_page).to have_enabled_for_success_toast("everyone")
    expect(item).to be_enabled

    upcoming_changes_page.visit
    expect(item).to be_enabled
    item.toggle
    expect(upcoming_changes_page).to have_disabled_success_toast

    upcoming_changes_page.visit
    expect(item).to be_disabled
  end

  it "keeps the configured audience when an admin switches a change off and on" do
    SiteSetting.enable_upload_debug_mode = true
    Fabricate(
      :site_setting_group,
      name: "enable_upload_debug_mode",
      group_ids: Group::AUTO_GROUPS[:trust_level_4].to_s,
    )
    upcoming_changes_page.visit
    item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
    item.toggle_groups
    expect(item).to have_groups("trust_level_4")

    item.toggle
    expect(upcoming_changes_page).to have_disabled_success_toast
    upcoming_changes_page.visit
    expect(item).to be_disabled
    item.toggle_groups
    expect(item).to have_groups("trust_level_4")

    item.toggle
    expect(item).to be_enabled
    upcoming_changes_page.visit
    item.toggle_groups
    expect(item).to have_groups("trust_level_4")
    expect(item).to be_enabled
  end

  it "lets an admin refine the default audience by saving group changes" do
    upcoming_changes_page.visit
    item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
    item.toggle
    expect(upcoming_changes_page).to have_enabled_for_success_toast("everyone")
    item.toggle_groups
    expect(item).to have_groups("logged_in_users", "anonymous_users")
    item.remove_group("anonymous_users")
    item.save_groups
    expect(upcoming_changes_page).to have_groups_updated_success_toast

    upcoming_changes_page.visit
    item.toggle_groups
    expect(item).to have_groups("logged_in_users")
    item.add_group("trust_level_4")
    item.save_groups
    expect(upcoming_changes_page).to have_groups_updated_success_toast

    upcoming_changes_page.visit
    item.toggle_groups
    expect(item).to have_groups("logged_in_users", "trust_level_4")
  end

  context "when an upcoming change uses a linked group setting" do
    before do
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          impact: "other,developers",
          impact_type: "other",
          impact_role: "developers",
          status: :experimental,
          group_setting: :hidden_post_visible_groups,
        },
      )
    end

    it "lets an admin save the audience separately and retains its mandatory groups" do
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      expect(item).to be_disabled
      item.toggle_groups
      expect(item).to have_groups("admins", "moderators", "trust_level_4")
      expect(item).to have_locked_group("admins")
      expect(item).to have_locked_group("moderators")
      item.remove_group("trust_level_4")
      item.add_group("trust_level_2")
      expect(item).to be_disabled
      item.save_groups
      expect(upcoming_changes_page).to have_groups_updated_success_toast
      expect(item).to be_disabled

      upcoming_changes_page.visit
      item.toggle_groups
      expect(item).to have_groups("admins", "moderators", "trust_level_2")
      item.toggle
      expect(item).to be_enabled

      upcoming_changes_page.visit
      expect(item).to be_enabled
      item.toggle_groups
      expect(item).to have_groups("admins", "moderators", "trust_level_2")
    end

    it "requires a nonempty linked audience before saving without changing the flag" do
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          impact: "other,developers",
          impact_type: "other",
          impact_role: "developers",
          status: :experimental,
          group_setting: :about_page_extra_groups,
        },
      )
      SiteSetting.about_page_extra_groups = "12"
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      item.toggle_groups
      expect(item).to have_groups("trust_level_2")
      item.remove_group("trust_level_2")
      expect(item).to have_disabled_group_save
      expect(item).to have_empty_groups_description
      expect(item).to be_disabled

      upcoming_changes_page.visit
      item.toggle_groups
      expect(item).to have_groups("trust_level_2")
      expect(item).to be_disabled
    end
  end

  describe "allow_enabled_for restrictions" do
    def mock_with_allow(allow)
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
            allow_enabled_for: allow,
          },
        },
      )
    end

    it "offers only a toggle for changes limited to everyone" do
      mock_with_allow([:everyone])
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      expect(item).to have_no_group_button
      item.toggle
      expect(item).to be_enabled
    end

    it "offers only a toggle for changes limited to staff" do
      mock_with_allow([:staff])
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      expect(item).to have_no_group_button
      item.toggle
      expect(upcoming_changes_page).to have_enabled_for_success_toast(
        "staff",
        translation_args: {
          staffGroupName: Group.find(Group::AUTO_GROUPS[:staff]).name,
        },
      )
      expect(item).to be_enabled
    end

    it "keeps staff locked while letting an admin include additional groups" do
      mock_with_allow(%i[staff specific_groups])
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      item.toggle
      expect(item).to be_enabled
      item.toggle_groups
      expect(item).to have_groups("staff")
      expect(item).to have_locked_group("staff")
      expect(item).to have_staff_description
      item.add_group("trust_level_4")
      item.save_groups
      expect(upcoming_changes_page).to have_groups_updated_success_toast

      upcoming_changes_page.visit
      item.toggle_groups
      expect(item).to have_groups("staff", "trust_level_4")
      expect(item).to have_locked_group("staff")
      expect(item).to have_staff_description
    end

    it "asks for a group before enabling a change limited to specific groups" do
      mock_with_allow([:specific_groups])
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      item.toggle
      expect(item).to be_disabled
      expect(item).to have_no_groups
      item.add_group("trust_level_4")
      item.save_groups
      expect(upcoming_changes_page).to have_enabled_for_success_toast(
        "specific_groups_with_group_names",
        translation_args: {
          groupNames: "trust_level_4",
          count: 1,
        },
      )
      expect(item).to be_enabled

      upcoming_changes_page.visit
      item.toggle_groups
      expect(item).to have_groups("trust_level_4")
      item.remove_group("trust_level_4")
      item.save_groups
      expect(upcoming_changes_page).to have_disabled_success_toast
      expect(item).to be_disabled
    end

    it "offers group refinement when allow_enabled_for is omitted" do
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      expect(item).to have_group_button
      expect(item).to have_no_group_selector
      item.toggle_groups
      expect(item).to have_groups("logged_in_users", "anonymous_users")
      expect(item).to be_disabled
    end

    it "shows auto-promoted changes as enabled before an admin configures their scope" do
      mock_with_allow(%i[staff specific_groups])
      SiteSetting.enable_upload_debug_mode = true
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      expect(item).to be_enabled
      item.toggle_groups
      expect(item).to have_groups("staff")
    end
  end

  it "can filter by name, description, plugin, status, impact type, or enabled/disabled" do
    upcoming_changes_page.visit

    # Filter by name
    upcoming_changes_page.filter_controls.type_in_search("upload debug")

    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.clear_search

    # Filter by plugin
    upcoming_changes_page.filter_controls.type_in_search("sample plugin")

    expect(upcoming_changes_page).to have_change(:enable_experimental_sample_plugin_feature)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    upcoming_changes_page.filter_controls.clear_search

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

  it "updates the filter when a notification is clicked while already on the page" do
    user_menu = PageObjects::Components::UserMenu.new

    Fabricate(
      :notification,
      user: current_user,
      notification_type: Notification.types[:upcoming_change_available],
      data: {
        upcoming_change_names: ["enable_upload_debug_mode"],
        upcoming_change_humanized_names: [
          SiteSettings::LabelFormatter.humanized_name(:enable_upload_debug_mode),
        ],
        count: 1,
      }.to_json,
    )
    Fabricate(
      :notification,
      user: current_user,
      notification_type: Notification.types[:upcoming_change_available],
      data: {
        upcoming_change_names: ["about_page_extra_groups_show_description"],
        upcoming_change_humanized_names: [
          SiteSettings::LabelFormatter.humanized_name(:about_page_extra_groups_show_description),
        ],
        count: 1,
      }.to_json,
    )

    visit "/"

    user_menu.open.click_notification_with_href("enable_upload_debug_mode")

    expect(upcoming_changes_page).to have_change(:enable_upload_debug_mode)
    expect(upcoming_changes_page).to have_no_change(:about_page_extra_groups_show_description)

    user_menu.open.click_notification_with_href("about_page_extra_groups_show_description")

    expect(upcoming_changes_page).to have_change(:about_page_extra_groups_show_description)
    expect(upcoming_changes_page).to have_no_change(:enable_upload_debug_mode)
  end

  it "displays a notification dot on the sidebar and clears it when navigating to upcoming changes" do
    sidebar = PageObjects::Components::NavigationMenu::Sidebar.new

    Discourse.stubs(:site_creation_date).returns(1.day.ago)

    UpcomingChangeEvent.create!(
      event_type: :added,
      upcoming_change_name: "enable_upload_debug_mode",
    )

    visit "/admin"
    sidebar.toggle_all_sections

    expect(sidebar.find_section_link("admin_upcoming_changes")).to have_css(
      ".sidebar-section-link-suffix.admin-sidebar-nav-link__dot",
    )

    sidebar.find_section_link("admin_upcoming_changes").click

    expect(sidebar.find_section_link("admin_upcoming_changes")).to have_no_css(
      ".sidebar-section-link-suffix.admin-sidebar-nav-link__dot",
    )
  end

  it "does not display a notification dot when there are no new added events" do
    sidebar = PageObjects::Components::NavigationMenu::Sidebar.new

    current_user.custom_fields["last_visited_upcoming_changes_at"] = Time.current.iso8601
    current_user.save_custom_fields

    visit "/admin"
    sidebar.toggle_all_sections

    expect(sidebar.find_section_link("admin_upcoming_changes")).to have_no_css(
      ".sidebar-section-link-suffix.admin-sidebar-nav-link__dot",
    )
  end

  context "when the staff group name has been localized" do
    before do
      SiteSetting.default_locale = "de"
      Group.refresh_automatic_group!(:staff)
    end

    it "lets an admin enable the change for the localized staff group" do
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          status: :experimental,
          allow_enabled_for: [:staff],
        },
      )
      upcoming_changes_page.visit
      item = upcoming_changes_page.change_item(:enable_upload_debug_mode)
      item.toggle
      expect(upcoming_changes_page).to have_enabled_for_success_toast(
        "staff",
        translation_args: {
          staffGroupName: Group.find(Group::AUTO_GROUPS[:staff]).name,
        },
      )
      expect(item).to be_enabled

      upcoming_changes_page.visit
      expect(item).to be_enabled
    end
  end

  context "when the upcoming change has a default override" do
    let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
      mock_upcoming_change_default_overrides(
        {
          suggested_topics_max_days_old: {
            upcoming_change: :enable_upload_debug_mode,
            new_default: 1000,
          },
        },
      )
      SiteSetting.enable_upload_debug_mode = true
      SiteSetting.refresh!
    end

    it "shows information about the default override in the site settings UI" do
      settings_page.visit("suggested_topics_max_days_old")
      expect(settings_page).to have_upcoming_change_default_warning(
        :suggested_topics_max_days_old,
        old_default: 365,
        new_default: 1000,
      )
    end
  end

  context "when the upcoming change has a boolean default override and the admin opts out" do
    let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "site_setting_default,all_members",
            status: :experimental,
            impact_type: "site_setting_default",
            impact_role: "all_members",
          },
        },
      )
      mock_upcoming_change_default_overrides(
        {
          limit_suggested_to_category: {
            upcoming_change: :enable_upload_debug_mode,
            new_default: true,
          },
        },
      )
      SiteSetting.enable_upload_debug_mode = true
      SiteSetting.refresh!
    end

    after do
      clear_mocked_upcoming_change_metadata
      clear_mocked_upcoming_change_default_overrides
    end

    it "preserves the admin's opt-out across page reload while still showing the override warning" do
      settings_page.visit("limit_suggested_to_category")

      expect(settings_page).to have_upcoming_change_default_warning(
        :limit_suggested_to_category,
        old_default: false,
        new_default: true,
      )
      expect(settings_page.bool_setting_checkbox(:limit_suggested_to_category)).to be_checked

      settings_page.toggle_bool_setting(:limit_suggested_to_category)

      # Wait for the save to land in the DB before forcing the in-process
      # SiteSetting refresh below — the .overridden class only appears once
      # the value has been persisted.
      expect(
        settings_page.find_setting(:limit_suggested_to_category, overridden: true),
      ).to be_present

      # Production reproduces the bug because each unicorn worker re-runs
      # SiteSetting.refresh! via the MessageBus subscriber after another
      # worker persists a setting change. In a single-process system spec
      # that subscriber doesn't fire, so we trigger the refresh explicitly
      # to mirror what happens on the next request in a real deployment.
      SiteSetting.refresh!

      page.refresh

      expect(settings_page).to have_upcoming_change_default_warning(
        :limit_suggested_to_category,
        old_default: false,
        new_default: true,
      )
      expect(settings_page.bool_setting_checkbox(:limit_suggested_to_category)).not_to be_checked
    end
  end
end
