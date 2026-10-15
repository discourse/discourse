# frozen_string_literal: true

describe "Admin Dashboard Community Health" do
  fab!(:current_user, :admin)

  before do
    SiteSetting.dashboard_improvements = false
    sign_in(current_user)
  end

  describe "Pageview Report" do
    context "when use_legacy_pageviews is true" do
      before { SiteSetting.use_legacy_pageviews = true }

      it "shows the 'Consolidated Pageviews' report" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(
          browser_root.locator(".admin-report.consolidated-page-views").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("reports.consolidated_page_views.title"))],
          useInnerText: true,
        )
      end
    end

    context "when use_legacy_pageviews is false" do
      before { SiteSetting.use_legacy_pageviews = false }

      it "shows the 'Site Traffic' report" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(
          browser_root.locator(".admin-report.site-traffic").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("reports.site_traffic.title"))],
          useInnerText: true,
        )
      end
    end
  end
end
