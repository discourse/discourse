# frozen_string_literal: true

# Photographs every reordering surface with `enable_new_reordering_controls`
# off and on, so the two arms can be compared side by side.
#
# TODO (ui-kit-reorderable-list-cleanup) delete this file once the change ships
# and there is only one arm left to photograph.
describe "Reordering surfaces" do
  fab!(:admin)
  fab!(:user_field) { Fabricate(:user_field, name: "Favourite colour") }
  fab!(:second_user_field) { Fabricate(:user_field, name: "Home town") }

  # A non-system grouping, so the badge groupings shot shows a row that can be
  # renamed and removed next to the ones that cannot.
  fab!(:custom_grouping) { BadgeGrouping.create!(name: "Custom grouping", position: 10) }

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:reports_dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:user_fields_page) { PageObjects::Pages::AdminUserFields.new }
  let(:badges_page) { PageObjects::Pages::AdminBadges.new }
  let(:flags_page) { PageObjects::Pages::AdminFlags.new }
  let(:section_modal) { PageObjects::Modals::SidebarSectionForm.new }
  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(admin)
  end

  [false, true].each do |enabled|
    suffix = enabled ? "on" : "off"

    context "with the change #{suffix}" do
      before { SiteSetting.enable_new_reordering_controls = enabled }

      it "photographs the dashboard configure menu" do
        dashboard.visit
        dashboard.open_configure_menu

        expect(page).to have_css(".db-configure__row")
        screenshot_marker(label: "reorder-configure-menu-#{suffix}")
      end

      it "photographs the manage reports modal" do
        AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
        AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

        page.visit("/admin")
        reports_dashboard.open_manage_reports_via_cog

        expect(page).to have_css(".manage-reports .manageable-row-list__row")
        screenshot_marker(label: "reorder-manage-reports-#{suffix}")
      end

      it "photographs the compare groups modal" do
        page.visit("/admin")
        find(".db-whos-posting__add-group").click

        expect(page).to have_css(".compare-groups .manageable-row-list__row")
        screenshot_marker(label: "reorder-compare-groups-#{suffix}")
      end

      it "photographs a simple-list setting" do
        settings_page.visit("top_menu")

        expect(page).to have_css(".value-list .value")
        screenshot_marker(label: "reorder-simple-list-#{suffix}")
      end

      it "photographs a value-list setting" do
        SiteSetting.exclude_rel_nofollow_domains = "example.com|discourse.org"
        settings_page.visit("exclude_rel_nofollow_domains")

        expect(page).to have_css(".value-list .value")
        screenshot_marker(label: "reorder-value-list-#{suffix}")
      end

      it "photographs an emoji-list setting" do
        settings_page.visit("default_emoji_reactions")

        expect(page).to have_css(".value-list")
        screenshot_marker(label: "reorder-emoji-list-#{suffix}")
      end

      it "photographs the admin flags table" do
        flags_page.visit

        expect(page).to have_css(".admin-flag-item")
        screenshot_marker(label: "reorder-admin-flags-#{suffix}")
      end

      it "photographs the user fields table" do
        user_fields_page.visit

        expect(page).to have_css(".admin-user_field-item")
        screenshot_marker(label: "reorder-user-fields-#{suffix}")
      end

      it "photographs the badge groupings modal" do
        badges_page.visit_page(Badge::Autobiographer).edit_groupings

        expect(page).to have_css(".badge-grouping-item")
        screenshot_marker(label: "reorder-badge-groupings-#{suffix}")
      end

      it "photographs the directory columns modal" do
        page.visit("/u")
        find(".open-edit-columns-btn").click

        expect(page).to have_css(".edit-directory-column")
        screenshot_marker(label: "reorder-directory-columns-#{suffix}")
      end

      it "photographs the sidebar section form" do
        visit("/latest")
        sidebar.click_add_section_button
        expect(section_modal).to be_visible

        section_modal.fill_name("My section")
        section_modal.fill_link("Sidebar Tags", "/tags")
        section_modal.add_link
        section_modal.fill_last_link("Sidebar Categories", "/categories")

        screenshot_marker(label: "reorder-sidebar-links-#{suffix}")
      end
    end
  end
end
