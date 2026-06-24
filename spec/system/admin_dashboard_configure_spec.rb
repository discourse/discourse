# frozen_string_literal: true

describe "Admin Dashboard Configure menu" do
  fab!(:admin)
  fab!(:moderator)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before { SiteSetting.dashboard_improvements = true }

  context "as an admin" do
    before { sign_in(admin) }

    it "applies toggles immediately, persists across reload, and shows an empty state when everything is hidden" do
      dashboard.visit
      expect(dashboard).to have_configure_button
      %w[highlights reports traffic engagement search].each do |id|
        expect(dashboard).to have_section(id)
      end

      dashboard.open_configure_menu.toggle_section("traffic").toggle_section("engagement")

      # changes apply right away, while the menu is still open
      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_section("search")
      expect(dashboard).to have_no_section("traffic")
      expect(dashboard).to have_no_section("engagement")

      dashboard.close_configure_menu
      page.refresh

      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_section("search")
      expect(dashboard).to have_no_section("traffic")
      expect(dashboard).to have_no_section("engagement")

      dashboard
        .open_configure_menu
        .toggle_section("highlights")
        .toggle_section("reports")
        .toggle_section("search")

      expect(dashboard).to have_empty_state
    end

    it "keeps a section's position when it is toggled off and back on" do
      dashboard.visit
      expect(dashboard.section_ids_in_order).to eq(%w[highlights reports traffic engagement search])

      dashboard.open_configure_menu.toggle_section("highlights")
      expect(dashboard).to have_no_section("highlights")

      dashboard.toggle_section("highlights")

      # it reappears in its original slot, not pushed to the bottom
      expect(dashboard).to have_first_section("highlights")
      expect(dashboard.section_ids_in_order).to eq(%w[highlights reports traffic engagement search])
    end

    it "reorders sections via the arrow buttons on mobile", mobile: true do
      dashboard.visit

      dashboard.open_configure_menu.move_section_up("reports")

      # reorder applies immediately, without closing the menu
      expect(dashboard).to have_first_section("reports")
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
      AdminDashboardSectionConfiguration.update(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: false },
          { id: "engagement", visible: false },
        ],
        actor: admin,
      )
      dashboard.visit

      expect(dashboard).to have_section("highlights")
      expect(dashboard).to have_section("reports")
      expect(dashboard).to have_no_section("traffic")
    end
  end
end
