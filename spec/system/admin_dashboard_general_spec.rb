# frozen_string_literal: true

describe "Admin Dashboard General Tab" do
  fab!(:admin)
  fab!(:user)
  fab!(:user_visit) { Fabricate(:user_visit, user: admin) }
  fab!(:user_visit_2) { Fabricate(:user_visit, user: user, mobile: true) }
  fab!(:user_visit_3) { Fabricate(:user_visit, user: user, visited_at: 1.day.ago) }

  before do
    SiteSetting.dashboard_improvements = false
    sign_in(admin)
  end

  it "displays correct visit counters combining desktop and mobile visits" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    within_browser(
      browser_root.locator(".admin-report.visits .admin-report-counters").filter(visible: true),
    ) do
      expect(
        browser_root.locator(".today-count").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("2")], useInnerText: true)
      expect(
        browser_root.locator(".yesterday-count").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("1")], useInnerText: true)
    end
  end
end
