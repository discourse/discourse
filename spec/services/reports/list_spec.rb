# frozen_string_literal: true

RSpec.describe Reports::List do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:current_user) { Fabricate(:admin) }

    let(:dependencies) { { guardian: current_user.guardian } }

    it "does not include the about or storage_stats reports" do
      expect(result[:reports].map { |r| r[:type] }).not_to include("about", "storage_stats")
    end

    it "does not include any mobile versions of page_view reports" do
      expect(
        result[:reports].filter { |r| r[:type].starts_with?("page_view") }.map { |r| r[:type] },
      ).not_to include(
        "page_view_logged_in_mobile_reqs",
        "page_view_anon_mobile_reqs",
        "page_view_anon_browser_mobile_reqs",
        "page_view_logged_in_browser_mobile_reqs",
      )
    end

    it "sorts reports by title" do
      expect(result[:reports].map { |r| r[:title] }[0..4]).to eq(
        [
          I18n.t("reports.staff_logins.title"),
          I18n.t("reports.page_view_anon_browser_reqs.title"),
          I18n.t("reports.bookmarks.title"),
          I18n.t("reports.consolidated_api_requests.title"),
          I18n.t("reports.dau_by_mau.title"),
        ],
      )
    end

    context "when using legacy pageviews" do
      before { SiteSetting.use_legacy_pageviews = true }

      it "includes all of the correct page view reports in the result" do
        expect(
          result[:reports].filter { |r| r[:type].starts_with?("page_view") }.map { |r| r[:type] },
        ).to match_array(
          %w[
            page_view_total_reqs
            page_view_crawler_reqs
            page_view_logged_in_reqs
            page_view_anon_reqs
            page_view_anon_browser_reqs
            page_view_logged_in_browser_reqs
          ],
        )
      end

      it "changes the title and description for consolidated_page_views and consolidated_page_views_browser_detection reports" do
        consolidated_page_views =
          result[:reports].find { |r| r[:type] == "consolidated_page_views" }
        consolidated_page_views_browser_detection =
          result[:reports].find { |r| r[:type] == "consolidated_page_views_browser_detection" }

        expect(consolidated_page_views[:title]).to eq(
          I18n.t("reports.consolidated_page_views.title_legacy"),
        )
        expect(consolidated_page_views[:description]).to eq(
          I18n.t("reports.consolidated_page_views.description_legacy"),
        )
        expect(consolidated_page_views_browser_detection[:title]).to eq(
          I18n.t("reports.consolidated_page_views_browser_detection.title_legacy"),
        )
        expect(consolidated_page_views_browser_detection[:description]).to eq(
          I18n.t("reports.consolidated_page_views_browser_detection.description_legacy"),
        )
      end
    end

    context "when not using legacy pageviews" do
      before { SiteSetting.use_legacy_pageviews = false }

      it "includes all of the correct page view reports in the result" do
        expect(
          result[:reports].filter { |r| r[:type].starts_with?("page_view") }.map { |r| r[:type] },
        ).to match_array(
          %w[
            page_view_total_reqs
            page_view_crawler_reqs
            page_view_anon_browser_reqs
            page_view_logged_in_browser_reqs
            page_view_legacy_total_reqs
          ],
        )
      end
    end
  end
end
