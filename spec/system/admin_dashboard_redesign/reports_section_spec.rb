# frozen_string_literal: true

describe "Admin Dashboard Redesign | Reports section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:modal) { PageObjects::Components::ManageReportsModal.new }

  before do
    SiteSetting.dashboard_improvements = true
    AdminDashboardSectionConfiguration.update(
      [
        { id: "reports", visible: true },
        { id: "highlights", visible: false },
        { id: "traffic", visible: false },
        { id: "engagement", visible: false },
      ],
      actor: current_user,
    )
    AdminDashboardReport.delete_all
    sign_in(current_user)
  end

  it "shows drag controls only once more than one report is enabled" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog
    expect(modal).to have_open
    expect(modal).to have_no_drag_controls

    modal.toggle("core_report:admin_logins")
    expect(modal).to have_drag_controls
  end

  it "disables the reorder arrows at the ends of the enabled list on mobile", mobile: true do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
    AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog
    expect(modal).to have_open

    expect(modal).to have_disabled_move_up("core_report:signups")
    expect(modal).to have_enabled_move_down("core_report:signups")
    expect(modal).to have_enabled_move_up("core_report:topics")
    expect(modal).to have_disabled_move_down("core_report:topics")
  end

  it "lets admins customize the reports section via the manage-reports modal" do
    AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
    AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

    page.visit("/admin")
    expect(dashboard).to have_section
    expect(dashboard.card_identifiers).to eq(%w[core_report:signups core_report:topics])

    dashboard.open_manage_reports_via_cog
    expect(modal).to have_open
    expect(modal.enabled_identifiers).to eq(%w[core_report:signups core_report:topics])
    expect(modal).to have_toggle_on("core_report:signups")
    expect(modal).to have_toggle_off("core_report:admin_logins")

    modal.search("admin_logins")
    expect(modal).to have_all_row("core_report:admin_logins")
    expect(modal).to have_no_all_row("core_report:dau_by_mau")
    modal.search("")

    modal.toggle("core_report:admin_logins")
    expect(modal).to have_toggle_on("core_report:admin_logins")
    modal.apply
    expect(modal).to have_closed
    expect(dashboard.card_identifiers).to contain_exactly(
      "core_report:signups",
      "core_report:topics",
      "core_report:admin_logins",
    )

    page.refresh
    expect(dashboard.card_identifiers).to contain_exactly(
      "core_report:signups",
      "core_report:topics",
      "core_report:admin_logins",
    )

    dashboard.open_manage_reports_via_tile
    expect(modal).to have_open
    modal.toggle("core_report:posts")
    modal.close
    expect(modal).to have_closed
    expect(dashboard.card_identifiers).to contain_exactly(
      "core_report:signups",
      "core_report:topics",
      "core_report:admin_logins",
    )
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

  it "does not render a label pill for standard reports" do
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
end
