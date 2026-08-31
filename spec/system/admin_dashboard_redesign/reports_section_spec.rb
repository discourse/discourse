# frozen_string_literal: true

describe "Admin Dashboard Redesign | Reports section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:modal) do
    PageObjects::Components::ManageableRowListModal.new(
      ".manage-reports",
      "admin_js.admin.dashboard.reports_section.modal.counter",
    )
  end

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

  # TODO (ui-kit-reorderable-list-cleanup) fold these over the examples above
  # once the change ships and the arrow buttons are gone.
  context "when enable_new_reordering_controls is enabled" do
    before { SiteSetting.enable_new_reordering_controls = true }

    it "marks the unavailable destinations at the ends of the enabled list on mobile",
       mobile: true do
      AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
      AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

      page.visit("/admin")
      dashboard.open_manage_reports_via_cog
      expect(modal).to have_open

      expect(modal).to have_no_move_up("core_report:signups")
      expect(modal).to have_move_down("core_report:signups")
      expect(modal).to have_move_up("core_report:topics")
      expect(modal).to have_no_move_down("core_report:topics")
    end

    it "lets the admin select a report's text" do
      # A row is a drag source, and a draggable element turns a press-drag into a
      # drag rather than a selection. The grip is what should be draggable, so the
      # title and description stay selectable like any other text.
      #
      # drag_with_pointer, not drag_and_drop: the latter goes through CDP drag
      # interception, which suppresses the ordinary mouse moves a selection is
      # made of. And a real pointer is the only thing that can select at all, as
      # a synthetic drag never touches the browser's selection.
      AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
      AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

      page.visit("/admin")
      dashboard.open_manage_reports_via_cog
      expect(modal).to have_open

      drag_with_pointer(
        from: ".manageable-row-list__row.--enabled .manageable-row-list__title",
        by: {
          x: 60,
        },
      )

      expect(page.evaluate_script("window.getSelection().toString()")).to be_present
    end

    it "reorders reports with a real browser drag" do
      AdminDashboardReport.create!(source: "core_report", identifier: "signups", position: 0)
      AdminDashboardReport.create!(source: "core_report", identifier: "topics", position: 1)

      page.visit("/admin")
      dashboard.open_manage_reports_via_cog
      expect(modal).to have_open

      modal.drag_report("core_report:topics", "core_report:signups")

      try_until_success do
        expect(modal.enabled_identifiers).to eq(%w[core_report:topics core_report:signups])
      end
    end
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
