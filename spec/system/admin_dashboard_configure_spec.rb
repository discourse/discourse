# frozen_string_literal: true

describe "Admin Dashboard Configure menu" do
  fab!(:admin)
  fab!(:moderator)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.admin_dashboard_sections = "highlights|reports|traffic|engagement"
  end

  context "as an admin" do
    before { sign_in(admin) }

    it "toggles section visibility from the Configure menu, persists across reload, and shows an empty state when everything is hidden" do
      dashboard.visit
      expect(dashboard).to have_configure_button
      %w[highlights reports traffic engagement].each { |id| expect(dashboard).to have_section(id) }

      dashboard
        .open_configure_menu
        .toggle_section("traffic")
        .toggle_section("engagement")
        .close_configure_menu

      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_no_section("traffic")
      expect(dashboard).to have_no_section("engagement")

      page.refresh

      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_no_section("traffic")
      expect(dashboard).to have_no_section("engagement")

      dashboard
        .open_configure_menu
        .toggle_section("highlights")
        .toggle_section("reports")
        .close_configure_menu

      expect(dashboard).to have_empty_state
    end

    it "reorders sections via the arrow buttons on mobile", mobile: true do
      dashboard.visit

      dashboard.open_configure_menu.move_section_up("reports").close_configure_menu

      expect(page).to have_css(".db-main__section:first-child[data-section-id='reports']")
      expect(dashboard.section_ids_in_order.first(2)).to eq(%w[reports highlights])
    end
  end

  context "as a moderator" do
    before { sign_in(moderator) }

    it "does not show the Configure trigger" do
      dashboard.visit
      expect(dashboard).to have_no_configure_button
    end

    it "sees the same configured layout an admin set up" do
      SiteSetting.admin_dashboard_sections = "highlights|reports"
      dashboard.visit

      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_no_section("traffic")
    end
  end
end
