# frozen_string_literal: true

describe "Admin Dashboard General Tab" do
  fab!(:admin)
  fab!(:user)
  fab!(:user_visit) { Fabricate(:user_visit, user: admin) }
  fab!(:user_visit_2) { Fabricate(:user_visit, user: user, mobile: true) }
  fab!(:user_visit_3) { Fabricate(:user_visit, user: user, visited_at: 1.day.ago) }

  before { sign_in(admin) }

  context "when reporting_improvements is enabled" do
    before { SiteSetting.reporting_improvements = true }

    it "displays correct visit counters combining desktop and mobile visits" do
      visit("/admin")

      within ".admin-report.visits .admin-report-counters" do
        expect(page).to have_css(".today-count", text: "2")
        expect(page).to have_css(".yesterday-count", text: "1")
      end
    end
  end

  context "when reporting_improvements is disabled" do
    before { SiteSetting.reporting_improvements = false }

    it "displays correct visit counters" do
      visit("/admin")

      within ".admin-report.visits .admin-report-counters" do
        expect(page).to have_css(".today-count", text: "2")
        expect(page).to have_css(".yesterday-count", text: "1")
      end
    end
  end
end
