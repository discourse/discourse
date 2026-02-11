# frozen_string_literal: true

describe "Admin Reports", type: :system do
  fab!(:current_user, :admin)
  before { sign_in(current_user) }

  context "when use_legacy_pageviews is true" do
    before { SiteSetting.use_legacy_pageviews = true }

    it "redirects from site_traffic to consolidated_page_views" do
      visit "/admin/reports/site_traffic"
      expect(page).to have_current_path("/admin/reports/consolidated_page_views")
    end
  end

  context "when use_legacy_pageviews is false" do
    before { SiteSetting.use_legacy_pageviews = false }

    it "won't redirects from site_traffic to consolidated_page_views" do
      visit "/admin/reports/site_traffic"
      expect(page).to have_current_path("/admin/reports/site_traffic")
    end
  end

  context "with legacy reports" do
    it "does not list bookmarks on the index page but allows direct access with a warning" do
      visit "/admin/reports"

      expect(page).to have_no_css(
        ".admin-section-landing-item__title",
        text: I18n.t("reports.bookmarks.title"),
      )

      visit "/admin/reports/bookmarks"

      expect(page).to have_css(".admin-report")
      expect(page).to have_css(
        ".alert.alert-info",
        text: I18n.t("admin_js.admin.reports.legacy_warning"),
      )
    end
  end
end
