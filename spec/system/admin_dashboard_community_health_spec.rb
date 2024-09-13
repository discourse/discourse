# frozen_string_literal: true

describe "Admin Dashboard Community Health", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  describe "Pageview Report" do
    context "when use_legacy_pageviews is true" do
      before { SiteSetting.use_legacy_pageviews = true }

      it "shows the 'Consolidated Pageviews' report" do
        visit("/admin")
        expect(page).to have_css(
          ".admin-report.consolidated-page-views",
          text: I18n.t("reports.consolidated_page_views.title"),
        )
      end
    end

    context "when use_legacy_pageviews is false" do
      before { SiteSetting.use_legacy_pageviews = false }

      it "shows the 'Site Traffic' report" do
        visit("/admin")
        expect(page).to have_css(
          ".admin-report.site-traffic",
          text: I18n.t("reports.site_traffic.title"),
        )
      end
    end
  end
end
