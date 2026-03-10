# frozen_string_literal: true

describe "Admin Dashboard General Tab", type: :system do
  fab!(:admin)

  before do
    freeze_time DateTime.parse("2026-03-09")

    sign_in(current_user)

    UserVisit.create!(user_id: current_user.id, visited_at: Date.today, mobile: false)
    UserVisit.create!(user_id: Fabricate(:user).id, visited_at: Date.today, mobile: true)
    UserVisit.create!(user_id: Fabricate(:user).id, visited_at: 1.day.ago.to_date, mobile: false)
  end

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
