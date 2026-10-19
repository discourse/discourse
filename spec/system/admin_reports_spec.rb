# frozen_string_literal: true

describe "Admin Reports" do
  fab!(:current_user, :admin)

  let(:reports_page) { PageObjects::Pages::AdminReport.new }

  before { sign_in(current_user) }

  context "when use_legacy_pageviews is true" do
    before { SiteSetting.use_legacy_pageviews = true }

    it "redirects from site_traffic to consolidated_page_views" do
      browser_page
        .goto("/admin/reports/site_traffic")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_page).to have_url("/admin/reports/consolidated_page_views")
    end
  end

  context "when use_legacy_pageviews is false" do
    before { SiteSetting.use_legacy_pageviews = false }

    it "does not redirect site_traffic to consolidated_page_views" do
      browser_page
        .goto("/admin/reports/site_traffic")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_page).to have_url("/admin/reports/site_traffic")
    end
  end

  it "groups reports under headings, hides legacy reports from the index, and warns on direct access" do
    browser_page.goto("/admin/reports").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    within_browser(
      browser_root
        .locator(".admin-reports-group")
        .filter(visible: true)
        .filter(hasText: browser_text_pattern("Engagement")),
    ) do
      expect(
        browser_root.locator(".admin-section-landing-item__title").filter(visible: true),
      ).to contain_text([browser_text_pattern(I18n.t("reports.signups.title"))], useInnerText: true)
    end
    expect(
      browser_root.locator(".admin-reports-group__title").filter(visible: true),
    ).to contain_text([browser_text_pattern("Traffic")], useInnerText: true)
    expect(
      browser_root.locator(".admin-section-landing-item__title").filter(visible: true),
    ).not_to contain_text(
      [browser_text_pattern(I18n.t("reports.bookmarks.title"))],
      useInnerText: true,
    )

    browser_page
      .goto("/admin/reports/bookmarks")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".admin-report").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".alert.alert-info").filter(visible: true)).to contain_text(
      [browser_text_pattern(I18n.t("admin_js.admin.reports.legacy_warning"))],
      useInnerText: true,
    )
  end

  it "lets admins pick multiple categories to filter a report" do
    category_1 = Fabricate(:category)
    category_2 = Fabricate(:category)

    reports_page.visit_report("activity_by_category")

    expect(reports_page).to have_rendered_report("activity_by_category")
    expect(reports_page).to have_category_filter

    filter = reports_page.category_filter
    filter.expand
    filter.select_row_by_value(category_1.id)
    filter.select_row_by_value(category_2.id)

    expect(reports_page).to have_selected_category(category_1)
    expect(reports_page).to have_selected_category(category_2)
  end

  it "lets admins filter report groups from URLs and controls" do
    reports_page.visit_index(group: "engagement")

    expect(reports_page).to have_current_reports_path(group: "engagement")
    expect(reports_page.filter_controls).to have_dropdown_value("Engagement")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_no_group("Traffic")

    reports_page.filter_controls.select_dropdown_option("Traffic")

    expect(reports_page).to have_current_reports_path(group: "traffic")
    expect(reports_page.filter_controls).to have_dropdown_value("Traffic")
    expect(reports_page).to have_group("Traffic")
    expect(reports_page).to have_no_group("Engagement")

    reports_page.filter_controls.select_all_dropdown_option

    expect(reports_page).to have_current_all_reports_path
    expect(reports_page.filter_controls).to have_dropdown_value("All groups")
    expect(reports_page).to have_group("Engagement")
    expect(reports_page).to have_group("Traffic")
  end
end
