# frozen_string_literal: true

RSpec.describe Reports::ListQuery do
  describe ".call" do
    subject(:result) { described_class.call(admin: true) }

    let(:result_page_view_report_types) do
      result.filter { |r| r[:type].starts_with?("page_view") }.map { |r| r[:type] }
    end

    it "does not include the about or storage_stats reports" do
      expect(result.map { |r| r[:type] }).not_to include("about", "storage_stats")
    end

    it "does not include any mobile versions of page_view reports" do
      expect(result_page_view_report_types).not_to include(
        "page_view_logged_in_mobile_reqs",
        "page_view_anon_mobile_reqs",
        "page_view_anon_browser_mobile_reqs",
        "page_view_logged_in_browser_mobile_reqs",
      )
    end

    it "sorts reports by title" do
      expect(result.map { |r| r[:title] }[0..4]).to eq(
        [
          I18n.t("reports.staff_logins.title"),
          I18n.t("reports.page_view_anon_browser_reqs.title"),
          I18n.t("reports.associated_accounts_by_provider.title"),
          I18n.t("reports.consolidated_api_requests.title"),
          I18n.t("reports.dau_by_mau.title"),
        ],
      )
    end

    context "when using legacy pageviews" do
      before { SiteSetting.use_legacy_pageviews = true }

      it "includes all of the correct page view reports in the result" do
        expect(result_page_view_report_types).to match_array(
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
        consolidated_page_views = result.find { |r| r[:type] == "consolidated_page_views" }
        consolidated_page_views_browser_detection =
          result.find { |r| r[:type] == "consolidated_page_views_browser_detection" }

        expect(consolidated_page_views).to include(
          title: I18n.t("reports.consolidated_page_views.title_legacy"),
          description: I18n.t("reports.consolidated_page_views.description_legacy"),
        )
        expect(consolidated_page_views_browser_detection).to include(
          title: I18n.t("reports.consolidated_page_views_browser_detection.title_legacy"),
          description:
            I18n.t("reports.consolidated_page_views_browser_detection.description_legacy"),
        )
      end
    end

    context "when not using legacy pageviews" do
      before { SiteSetting.use_legacy_pageviews = false }

      it "includes all of the correct page view reports in the result" do
        expect(result_page_view_report_types).to match_array(
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

    context "when admin is true" do
      subject(:result) { described_class.call(admin: true) }

      it "includes admin-only reports" do
        expect(result.map { |r| r[:type] }).to include(*Report::ADMIN_ONLY_REPORTS)
      end
    end

    context "when admin is false" do
      subject(:result) { described_class.call(admin: false) }

      it "excludes admin-only reports" do
        expect(result.map { |r| r[:type] }).not_to include(*Report::ADMIN_ONLY_REPORTS)
      end
    end

    it "does not include plugin name for core reports" do
      topics_report = result.find { |r| r[:type] == "topics" }
      expect(topics_report[:plugin]).to be_nil
    end

    context "with a plugin report" do
      let(:plugin) { Plugin::Instance.new }

      before do
        Report.add_report("test_plugin_report") { |report| }
        Discourse.plugins_by_name["test-plugin"] = plugin

        I18n.backend.store_translations(
          :en,
          { reports: { test_plugin_report: { title: "Test Plugin Report" } } },
        )
      end

      after do
        if Report.singleton_class.method_defined?(:report_test_plugin_report)
          Report.singleton_class.remove_method(:report_test_plugin_report)
        end
        Discourse.plugins_by_name.delete("test-plugin")
      end

      it "excludes reports when the source plugin is disabled" do
        plugin.stubs(:enabled?).returns(false)

        formatted = Reports::ListQuery::FormattedReport.new(:report_test_plugin_report)
        formatted.stubs(:resolve_plugin_name).returns("test-plugin")

        expect(formatted.to_h(admin: true)).to be_nil
      end

      it "includes reports when the source plugin is enabled" do
        plugin.stubs(:enabled?).returns(true)
        plugin.stubs(:humanized_name).returns("Test Plugin")

        formatted = Reports::ListQuery::FormattedReport.new(:report_test_plugin_report)
        formatted.stubs(:resolve_plugin_name).returns("test-plugin")

        result = formatted.to_h(admin: true)
        expect(result).to be_present
        expect(result[:plugin]).to eq("test-plugin")
        expect(result[:plugin_display_name]).to eq("Test Plugin")
      end
    end
  end
end
