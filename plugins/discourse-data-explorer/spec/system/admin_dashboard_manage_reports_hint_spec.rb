# frozen_string_literal: true

describe "Data Explorer | Manage Reports footer hint" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:modal) { PageObjects::Components::ManageReportsModal.new }
  let(:hint) { PageObjects::Components::AdminDashboardManageReportsHint.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.data_explorer_enabled = true
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

  it "renders the Create a Data Explorer query hint inside the Manage Reports modal" do
    page.visit("/admin")
    dashboard.open_manage_reports_via_cog

    expect(hint).to have_hint
  end

  it "links the hint to the Data Explorer new-query page" do
    page.visit("/admin")
    dashboard.open_manage_reports_via_cog

    hint.click_hint

    expect(page).to have_current_path("/admin/plugins/discourse-data-explorer/queries/new")
  end

  it "does not render the hint when the Data Explorer plugin is disabled" do
    SiteSetting.data_explorer_enabled = false

    page.visit("/admin")
    dashboard.open_manage_reports_via_cog

    expect(hint).to have_no_hint
  end
end
