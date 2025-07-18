# frozen_string_literal: true

RSpec.describe "Reports", type: :system, js: true do
  fab!(:group) { Fabricate(:group, name: "group") }
  fab!(:user) { Fabricate(:admin) }
  fab!(:group_user) { Fabricate(:group_user, user: user, group: group) }
  fab!(:query_1) do
    Fabricate(
      :query,
      name: "My First Query",
      description: "This is the description of my 1st query.",
      sql: "SELECT * FROM users limit 1",
      user: user,
    )
  end
  fab!(:query_2) do
    Fabricate(
      :query,
      name: "My Second Query",
      description: "This is my 2nd query's description.",
      sql: "SELECT * FROM users limit 1",
      user: user,
    )
  end
  fab!(:query_group_1) { Fabricate(:query_group, query: query_1, group: group) }
  fab!(:query_group_2) { Fabricate(:query_group, query: query_2, group: group) }

  before { SiteSetting.data_explorer_enabled = true }

  it "allows user to switch between reports" do
    sign_in(user)
    visit("/g/group/reports/#{query_2.id}")
    expect(find(".user-content h1")).to have_content("My Second Query")
    expect(page).not_to have_css(".query-results .result-header")
    find(".query-run .btn-primary").click
    expect(page).to have_css(".query-results .result-header")

    find(".group-reports-nav-item-outlet a").click
    all(".group-reports a ").last.click
    expect(find(".user-content h1")).to have_content("My Second Query")
    expect(page).not_to have_css(".query-results .result-header")
    find(".query-run .btn-primary").click
    expect(page).to have_css(".query-results .result-header")
  end

  it "allows user to run a report with a JSON column and open a fullscreen code viewer" do
    Fabricate(:reviewable_queued_post)
    sql = <<~SQL
      SELECT id, payload FROM reviewables LIMIT 10
    SQL
    json_query = DiscourseDataExplorer::Query.create!(name: "some query", sql: sql)
    sign_in(user)
    visit("/g/group/reports/#{json_query.id}")
    find(".query-run .btn-primary").click
    expect(page).to have_css(".query-results .result-json")
    first(".query-results .result-json .btn.result-json-button").click
    expect(page).to have_css(".fullscreen-code-modal")
  end
end
