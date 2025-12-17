# frozen_string_literal: true

RSpec.describe "Member upcoming changes", type: :system do
  fab!(:current_user, :user)
  fab!(:admin)
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

    SiteSetting.enable_upload_debug_mode = true
  end

  context "when user is logged in" do
    before { sign_in(current_user) }

    it "adds a body class for enabled upcoming changes for the member" do
      visit "/"
      expect(page).to have_css("body.uc-enable-upload-debug-mode")
      expect(page).to have_no_css("body.uc-about-page-extra-groups-show-description")
    end

    it "only adds a body class for upcoming changes enabled for the user's groups" do
      group = Fabricate(:group)
      Fabricate(:site_setting_group, name: "enable_upload_debug_mode", group_ids: group.id.to_s)
      visit "/"
      expect(page).to have_no_css("body.uc-enable-upload-debug-mode")

      group.add(current_user)
      visit "/"
      expect(page).to have_css("body.uc-enable-upload-debug-mode")
    end

    it "adds and removes the body class based on MessageBus subscription for client site settings" do
      visit "/"
      expect(page).to have_css("body.uc-enable-upload-debug-mode")

      using_session(:admin) do
        sign_in(admin)

        upcoming_changes_page.visit
        upcoming_changes_page.change_item(:enable_upload_debug_mode).select_enabled_for("no_one")
        expect(upcoming_changes_page).to have_disabled_success_toast
      end

      expect(page).to have_no_css("body.uc-enable-upload-debug-mode")
    end
  end

  context "when user is anonymous" do
    it "does not add any body classes for upcoming changes with groups" do
      Fabricate(
        :site_setting_group,
        name: "enable_upload_debug_mode",
        group_ids: Group::AUTO_GROUPS[:trust_level_1].to_s,
      )
      visit "/"
      expect(page).to have_no_css("body.uc-enable-upload-debug-mode")
      expect(page).to have_no_css("body.uc-about-page-extra-groups-show-description")
    end

    it "does add a body class for upcoming changes enabled for Everyone" do
      visit "/"
      expect(page).to have_css("body.uc-enable-upload-debug-mode")
      expect(page).to have_no_css("body.uc-about-page-extra-groups-show-description")
    end
  end
end
