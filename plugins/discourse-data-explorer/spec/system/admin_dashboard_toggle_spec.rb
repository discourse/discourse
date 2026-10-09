# frozen_string_literal: true

describe "Data Explorer | Add query to admin dashboard" do
  fab!(:current_user, :admin)
  fab!(:query) { Fabricate(:query, name: "Signups", sql: "SELECT 1 AS value", user: current_user) }

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }
  let(:dashboard) { PageObjects::Pages::AdminDashboardReports.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.data_explorer_enabled = true
    SiteSetting.data_explorer_ai_queries_enabled = false
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

  it "adds the query to the dashboard and removes it again" do
    query_runner.visit_admin_query(query.id)
    expect(query_runner).to have_dashboard_toggle("Add to dashboard")

    query_runner.click_dashboard_toggle

    expect(toasts).to have_success(I18n.t("js.explorer.dashboard.added"))
    expect(query_runner).to have_dashboard_toggle("Remove from dashboard")
    expect(
      AdminDashboardReport.exists?(source: "data_explorer_query", identifier: query.id.to_s),
    ).to eq(true)

    query_runner.click_dashboard_toggle

    expect(toasts).to have_success(I18n.t("js.explorer.dashboard.removed"))
    expect(query_runner).to have_dashboard_toggle("Add to dashboard")
    expect(AdminDashboardReport.count).to eq(0)
  end

  it "shows the added query on the admin dashboard" do
    query_runner.visit_admin_query(query.id)
    query_runner.click_dashboard_toggle
    expect(query_runner).to have_dashboard_toggle("Remove from dashboard")

    page.visit("/admin")

    expect(dashboard).to have_card("data_explorer_query:#{query.id}")
  end

  it "disables the button for a query with a required parameter" do
    query.update!(sql: "-- [params]\n-- int :num\nSELECT :num")

    query_runner.visit_admin_query(query.id)

    expect(query_runner).to have_disabled_dashboard_toggle
  end

  it "hides the button when the dashboard improvements are disabled" do
    SiteSetting.dashboard_improvements = false

    query_runner.visit_admin_query(query.id)

    expect(page).to have_css(".query-run-split__primary")
    expect(query_runner).to have_no_dashboard_toggle
  end
end
