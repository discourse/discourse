# frozen_string_literal: true

describe "Admin Dashboard Redesign | Reports section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:modal) { PageObjects::Components::ManageReportsModal.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.admin_dashboard_sections = "reports"
    AdminDashboardReport.delete_all
    sign_in(current_user)
  end

  it "renders the seeded core defaults as cards in admin-chosen order" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
    AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

    page.visit("/admin")
    expect(dashboard).to have_section
    expect(dashboard.card_identifiers).to eq(%w[core_report:signups core_report:topics])
  end

  it "removes a card immediately via X-to-remove" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
    AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

    page.visit("/admin")
    expect(dashboard).to have_card("core_report:signups")

    dashboard.remove_card("core_report:signups")

    expect(dashboard).to have_no_card("core_report:signups")
    expect(AdminDashboardReport.exists?(source: "core_report", identifier: "signups")).to eq(false)
  end

  it "opens the Manage Reports modal from the cog and from the Add Report tile" do
    page.visit("/admin")

    dashboard.open_manage_reports_via_cog
    expect(modal).to have_open

    modal.close
    expect(modal).to have_closed

    dashboard.open_manage_reports_via_tile
    expect(modal).to have_open
  end

  it "renders the All reports list with toggles reflecting the current state" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog

    expect(modal.enabled_identifiers).to eq(%w[core_report:signups])
    expect(modal).to have_toggle_on("core_report:signups")
    expect(modal).to have_toggle_off("core_report:admin_logins")
  end

  it "applies modal changes and persists them" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog
    expect(modal).to have_open
    expect(modal.enabled_identifiers).to eq(%w[core_report:signups])

    modal.toggle("core_report:admin_logins")
    expect(modal).to have_toggle_on("core_report:admin_logins")
    modal.apply

    expect(modal).to have_closed
    expect(dashboard.card_identifiers).to contain_exactly(
      "core_report:signups",
      "core_report:admin_logins",
    )
    expect(AdminDashboardReport.pluck(:identifier)).to contain_exactly("signups", "admin_logins")
  end

  it "discards changes when the modal is closed without applying" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog
    modal.toggle("core_report:admin_logins")
    modal.close

    expect(modal).to have_closed
    expect(dashboard.card_identifiers).to eq(%w[core_report:signups])
    expect(AdminDashboardReport.pluck(:identifier)).to eq(%w[signups])
  end

  it "hides the Add Report tile when the cap is reached" do
    identifiers =
      Reports::ListQuery
        .call(guardian: current_user.guardian)
        .first(AdminDashboardReport::VISIBLE_CAP)
        .map { |entry| entry[:type] }
    now = Time.current
    AdminDashboardReport.insert_all(
      identifiers.each_with_index.map do |identifier, i|
        {
          source: "core_report",
          identifier: identifier,
          position: i,
          created_at: now,
          updated_at: now,
        }
      end,
    )

    page.visit("/admin")
    expect(dashboard.card_identifiers.size).to eq(AdminDashboardReport::VISIBLE_CAP)
    expect(dashboard).to have_no_add_tile
  end

  it "hides provider label pills when only one provider is registered" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    page.visit("/admin")
    expect(dashboard).to have_no_label_for("core_report:signups")
  end

  it "lets moderators view the section but hides all edit affordances" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    sign_in(Fabricate(:moderator))
    page.visit("/admin")

    expect(dashboard).to have_card("core_report:signups")
    expect(dashboard).to have_no_cog
    expect(dashboard).to have_no_add_tile
    expect(dashboard).to have_no_remove_button("core_report:signups")
  end

  it "filters the All reports list via the sticky search input" do
    page.visit("/admin")
    dashboard.open_manage_reports_via_cog

    expect(modal).to have_all_row("core_report:admin_logins")

    modal.search("signups")

    expect(modal).to have_no_all_row("core_report:admin_logins")
    expect(modal).to have_all_row("core_report:signups")
  end
end
