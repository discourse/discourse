# frozen_string_literal: true

RSpec.describe "Reviewable links in Data Explorer" do
  fab!(:admin)
  fab!(:group) { Fabricate(:group, name: "reviewers") }
  fab!(:group_user) { Fabricate(:group_user, user: admin, group: group) }

  let(:query_runner) { PageObjects::Pages::DataExplorerQueryRunner.new }
  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  it "lets a reviewer open a reviewable from admin and shared query results" do
    reviewable = Fabricate(:reviewable_queued_post)
    query = Fabricate(:query, name: "Reviewable report", user: admin, sql: <<~SQL)
          SELECT reviewable_id
          FROM (
            SELECT id::text AS reviewable_id FROM reviewables WHERE id = #{reviewable.id}
            UNION ALL SELECT NULL AS reviewable_id
            UNION ALL SELECT 'invalid' AS reviewable_id
          ) AS results
        SQL
    Fabricate(:query_group, query: query, group: group)

    query_runner.visit_admin_query(query.id).run_query

    expect(query_runner).to have_result_heading("reviewable")
    expect(query_runner).to have_reviewable_link(reviewable)
    expect(query_runner).to have_plain_result_cell("NULL")
    expect(query_runner).to have_plain_result_cell("invalid")

    query_runner.click_reviewable_link(reviewable)
    expect(page).to have_current_path("/review/#{reviewable.id}")
    expect(review_page).to have_reviewables([reviewable])

    query_runner.visit_group_report(group.name, query.id)
    query_runner.run_shared_query

    expect(query_runner).to have_reviewable_link(reviewable)
  end
end
