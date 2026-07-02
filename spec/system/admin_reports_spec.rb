# frozen_string_literal: true

describe "Admin Reports" do
  fab!(:current_user, :admin)

  let(:reports_page) { PageObjects::Pages::AdminReport.new }

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

  it "groups reports under headings, hides legacy reports from the index, and warns on direct access" do
    visit "/admin/reports"

    within(".admin-reports-group", text: "Engagement") do
      expect(page).to have_css(
        ".admin-section-landing-item__title",
        text: I18n.t("reports.signups.title"),
      )
    end
    expect(page).to have_css(".admin-reports-group__title", text: "Traffic")
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

  it "lets admins use report group filters from URLs and controls" do
    Reports::ListQuery.stubs(:call).returns(
      [
        {
          type: "signups",
          title: I18n.t("reports.signups.title"),
          description: I18n.t("reports.signups.description"),
        },
        {
          type: "visits",
          title: I18n.t("reports.visits.title"),
          description: I18n.t("reports.visits.description"),
        },
        {
          type: "flags",
          title: I18n.t("reports.flags.title"),
          description: I18n.t("reports.flags.description"),
        },
        {
          type: "alpha_report",
          title: "Alpha report",
          description: "From alpha plugin",
          plugin: "alpha-plugin",
          plugin_display_name: "Alpha Metrics",
        },
      ],
    )

    reports_page.visit_index(group: "missing")

    expect(reports_page).to have_current_all_reports_path
    expect(reports_page.filter_controls).to have_dropdown_accessible_name("Report group")
    expect(reports_page.filter_controls).to have_dropdown_value("All groups")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_group("Moderation & Security")
    expect(reports_page).to have_group("Alpha Metrics")
    expect(reports_page).to have_static_group_heading("Engagement")
    expect(reports_page).to have_static_group_heading("Alpha Metrics")

    reports_page.visit_index(group: "plugin-missing")

    expect(reports_page).to have_current_all_reports_path
    expect(reports_page.filter_controls).to have_dropdown_accessible_name("Report group")
    expect(reports_page.filter_controls).to have_dropdown_value("All groups")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_group("Moderation & Security")
    expect(reports_page).to have_group("Alpha Metrics")
    expect(reports_page).to have_static_group_heading("Engagement")
    expect(reports_page).to have_static_group_heading("Alpha Metrics")

    reports_page.visit_index(group: "engagement")

    expect(reports_page).to have_current_reports_path(group: "engagement")
    expect(reports_page.filter_controls).to have_dropdown_accessible_name("Report group")
    expect(reports_page.filter_controls).to have_dropdown_value("Engagement")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_static_group_heading("Engagement")
    expect(reports_page).to have_no_group("Moderation & Security")
    expect(reports_page).to have_no_group("Alpha Metrics")
    expect(reports_page).to have_report(I18n.t("reports.signups.title"))
    expect(reports_page).to have_report(I18n.t("reports.visits.title"))
    expect(reports_page).to have_no_report(I18n.t("reports.flags.title"))
    expect(reports_page).to have_no_report("Alpha report")

    reports_page.filter_controls.type_in_search(I18n.t("reports.signups.title"))

    expect(reports_page).to have_report(I18n.t("reports.signups.title"))
    expect(reports_page).to have_no_report(I18n.t("reports.visits.title"))
    expect(reports_page.filter_controls).to have_no_no_results_reset_button

    reports_page.filter_controls.clear_search
    reports_page.filter_controls.type_in_search(I18n.t("reports.flags.title"))

    expect(reports_page.filter_controls).to have_no_results_message(
      I18n.t("admin_js.admin.filter_reports_no_results"),
    )

    reports_page.filter_controls.click_no_results_reset_button

    expect(reports_page).to have_current_all_reports_path
    expect(reports_page.filter_controls).to have_dropdown_value("All groups")
    expect(reports_page.filter_controls.search_input_value).to eq("")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_group("Moderation & Security")
    expect(reports_page).to have_group("Alpha Metrics")
    expect(reports_page).to have_report(I18n.t("reports.visits.title"))

    reports_page.filter_controls.select_dropdown_option("Moderation & Security")

    expect(reports_page).to have_current_reports_path(group: "moderation_and_security")
    expect(reports_page).to have_group("Moderation & Security")
    expect(reports_page).to have_no_group("Engagement")
    expect(reports_page).to have_no_group("Alpha Metrics")
  end

  it "lets admins open plugin report groups by stable slug" do
    Reports::ListQuery.stubs(:call).returns(
      [
        {
          type: "signups",
          title: I18n.t("reports.signups.title"),
          description: I18n.t("reports.signups.description"),
        },
        {
          type: "zebra_report",
          title: "Zebra report",
          description: "From zebra plugin",
          plugin: "zebra-plugin",
          plugin_display_name: "Zebra Analytics",
        },
        {
          type: "alpha_report",
          title: "Alpha report",
          description: "From alpha plugin",
          plugin: "alpha-plugin",
          plugin_display_name: "Alpha Metrics",
        },
      ],
    )

    reports_page.visit_index(group: "plugin-alpha-plugin")

    expect(reports_page).to have_current_reports_path(group: "plugin-alpha-plugin")
    expect(reports_page.filter_controls).to have_dropdown_accessible_name("Report group")
    expect(reports_page.filter_controls).to have_dropdown_value("Alpha Metrics")
    expect(reports_page).to have_group("Alpha Metrics")
    expect(reports_page).to have_no_group("Engagement")
    expect(reports_page).to have_no_group("Zebra Analytics")
    expect(reports_page).to have_report("Alpha report")
    expect(reports_page).to have_no_report(I18n.t("reports.signups.title"))
    expect(reports_page).to have_no_report("Zebra report")

    reports_page.filter_controls.select_dropdown_option("Zebra Analytics")

    expect(reports_page).to have_current_reports_path(group: "plugin-zebra-plugin")
    expect(reports_page).to have_group("Zebra Analytics")
    expect(reports_page).to have_no_group("Alpha Metrics")
  end
end
