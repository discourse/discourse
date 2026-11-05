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
end
