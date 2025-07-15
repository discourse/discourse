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
end
