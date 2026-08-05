# frozen_string_literal: true

describe "Admin Dashboard General Tab" do
  fab!(:admin)
  fab!(:user)
  fab!(:user_visit) { Fabricate(:user_visit, user: admin) }
  fab!(:user_visit_2) { Fabricate(:user_visit, user: user, mobile: true) }
  fab!(:user_visit_3) { Fabricate(:user_visit, user: user, visited_at: 1.day.ago) }

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = false
    sign_in(admin)
  end

  it "displays correct visit counters combining desktop and mobile visits" do
    dashboard.track_general_dashboard_requests.visit

    within ".admin-report.visits .admin-report-counters" do
      expect(page).to have_css(".today-count", text: "2")
      expect(page).to have_css(".yesterday-count", text: "1")
    end
    expect(dashboard.general_dashboard_request_count).to eq(1)
  end
end
