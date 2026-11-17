# frozen_string_literal: true

RSpec.describe "Browse queries" do
  fab!(:admin)
  fab!(:alice) { Fabricate(:user, username: "alice") }

  let(:queries_page) { PageObjects::Pages::DataExplorerQueries.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  it "lets the admin browse every query, its author, groups and last run" do
    DiscourseDataExplorer::DefaultQuerySync.execute
    recent = Fabricate(:query, user: alice, last_run_at: 1.hour.ago)
    widely_shared = Fabricate(:query, user: alice, last_run_at: 2.hours.ago)
    shared_groups = Fabricate.times(26, :group)
    shared_groups.each { |group| Fabricate(:query_group, query: widely_shared, group:) }
    never_run = Fabricate(:query, user: alice, last_run_at: nil)
    default_query = DiscourseDataExplorer::Query.where("id < 0").first

    queries_page.visit

    expect(queries_page).to have_author(recent, alice)
    expect(queries_page).to have_last_run(recent)
    expect(queries_page).to have_editable(recent)
    expect(queries_page).to have_groups(widely_shared, shared_groups)
    expect(queries_page).to have_query_count(50)

    queries_page.scroll_to_end

    expect(queries_page).to have_query_count(DiscourseDataExplorer::Query.count)
    expect(queries_page).to have_no_last_run(never_run)
    expect(queries_page).to have_view_only(default_query)
  end

  it "lets the admin narrow queries by tags and search, and keeps that when they come back" do
    monthly_revenue = Fabricate(:query, name: "Monthly revenue")
    refunds = Fabricate(:query, name: "Refunds")
    monthly_signups = Fabricate(:query, name: "Monthly signups")
    DiscourseDataExplorer::QueryTag.sync!(query: monthly_revenue, names: %w[finance monthly])
    DiscourseDataExplorer::QueryTag.sync!(query: refunds, names: %w[finance])
    DiscourseDataExplorer::QueryTag.sync!(query: monthly_signups, names: %w[monthly])

    queries_page.visit.filter_by_tag(monthly_revenue, "finance")

    expect(queries_page).to have_queries([monthly_revenue, refunds])

    queries_page.filter_by_tag(monthly_revenue, "monthly")

    expect(queries_page).to have_queries([monthly_revenue])

    queries_page.search("revenue").open(monthly_revenue).back_to_list

    expect(queries_page).to have_tag_filters(%w[finance monthly])
    expect(queries_page).to have_search("revenue")
    expect(queries_page).to have_queries([monthly_revenue])
  end

  it "lets the admin delete a query from the list" do
    DiscourseDataExplorer::DefaultQuerySync.execute
    obsolete = Fabricate(:query, name: "Zebra obsolete")
    kept = Fabricate(:query, name: "Zebra kept")
    default_query = DiscourseDataExplorer::Query.where("id < 0").first

    queries_page.visit.search("zebra").delete(obsolete)

    expect(queries_page).to have_no_query(obsolete)
    expect(queries_page).to have_queries([kept])
    expect(obsolete.reload).to be_hidden

    queries_page.search(default_query.name)

    expect(queries_page).to have_no_delete_option(default_query)
  end

  it "lets the admin add a query to the dashboard from the list and remove it again" do
    DiscourseDataExplorer::DefaultQuerySync.execute
    default_query = DiscourseDataExplorer::Query.where("id < 0").first
    report_scope =
      AdminDashboardReport.where(source: "data_explorer_query", identifier: default_query.id.to_s)

    queries_page.visit.search(default_query.name).toggle_dashboard(default_query)

    expect(queries_page).to have_dashboard_action(
      default_query,
      I18n.t("js.explorer.dashboard.remove"),
    )
    expect(report_scope).to exist

    queries_page.toggle_dashboard(default_query)

    expect(queries_page).to have_dashboard_action(
      default_query,
      I18n.t("js.explorer.dashboard.add"),
    )
    expect(report_scope).not_to exist
  end
end
