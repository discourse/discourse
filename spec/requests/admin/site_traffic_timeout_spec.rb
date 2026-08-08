# frozen_string_literal: true

RSpec.describe "Admin site traffic timeout" do
  fab!(:admin)

  before do
    SiteSetting.dashboard_improvements = true
    sign_in(admin)
  end

  it "returns a distinct timeout response" do
    AdminDashboardSiteTrafficExplorer.stubs(:call).raises(
      ActiveRecord::QueryCanceled,
      "statement timeout",
    )

    get "/admin/dashboard/traffic.json",
        params: {
          start_date: "2026-05-01",
          end_date: "2026-05-12",
        }

    expect(status: response.status, body: response.parsed_body).to eq(
      status: 503,
      body: {
        "error_type" => "traffic_query_timeout",
      },
    )
  end
end
