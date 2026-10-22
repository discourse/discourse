# frozen_string_literal: true

RSpec.describe "View onboarding reports" do
  fab!(:admin)
  fab!(:user)

  let(:checklist) { PageObjects::Pages::LovelaceMemberChecklist.new }
  let(:reports_page) { PageObjects::Pages::AdminReport.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  it "shows member activity and item completions in standard report tables" do
    checklist.open
    expect(checklist).to have_progress("0 of 3 complete")
    checklist.toggle("Complete your profile")
    expect(checklist).to have_progress("1 of 3 complete")
    checklist.dismiss
    expect(checklist).to have_no_checklist

    reports_page.visit_report("lovelace_onboarding")
    expect(reports_page).to have_rendered_report("lovelace_onboarding")
    expect(page).to have_css("tr", normalize_ws: true, text: "Seen the checklist 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Completed at least one item 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Completed all items —")
    expect(page).to have_css("tr", normalize_ws: true, text: "Dismissed the checklist 1")
    expect(page).to have_css(
      "tr",
      normalize_ws: true,
      text: "Dismissed without completing any items —",
    )

    expect(page.all(".lovelace-onboarding td.activity").map(&:text)).to eq(
      [
        "Seen the checklist",
        "Clicked at least one item link",
        "Completed at least one item",
        "Clicked all item links",
        "Completed all items",
        "Dismissed the checklist",
        "Dismissed without completing any items",
      ],
    )
    expect(page).to have_no_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
    reports_page.visit_report("lovelace_onboarding_items")
    expect(reports_page).to have_rendered_report("lovelace_onboarding_items")
    expect(page).to have_css("tr", normalize_ws: true, text: "Complete your profile — 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Add a profile picture — —")
    expect(page).to have_css("th", text: "Clicked item link")
    expect(page).to have_css("th", text: "Marked item complete")
    expect(page).to have_no_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
    page.refresh
    expect(page).to have_css("tr", normalize_ws: true, text: "Complete your profile — 1")
  end

  it "reports a member's link activations separately from checked items without changing navigation" do
    guidelines = Fabricate(:post)
    SiteSetting.guidelines_topic_id = guidelines.topic_id
    sign_in(user)
    checklist.open
    expect(checklist).to have_progress("0 of 3 complete")
    checklist.follow_guidelines
    expect(page).to have_current_path(guidelines.topic.relative_url)
    checklist.open
    expect(checklist).to have_progress("0 of 3 complete")

    sign_in(admin)
    reports_page.visit_report("lovelace_onboarding")
    expect(reports_page).to have_rendered_report("lovelace_onboarding")
    expect(page).to have_css("tr", normalize_ws: true, text: "Clicked at least one item link 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Clicked all item links —")
    expect(page).to have_no_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
    reports_page.visit_report("lovelace_onboarding_items")
    expect(page).to have_css("tr", normalize_ws: true, text: "Read community guidelines 1 —")

    sign_in(user)
    checklist.open
    checklist.follow_link_with_keyboard("Add picture")
    expect(page).to have_current_path("/u/#{user.username_lower}/preferences/account")
    checklist.open
    checklist.follow_link_with_keyboard("Complete profile")
    expect(page).to have_current_path("/u/#{user.username_lower}/preferences/profile")
    checklist.open
    checklist.follow_guidelines
    expect(page).to have_current_path(guidelines.topic.relative_url)
    checklist.open
    checklist.toggle("Complete your profile")
    expect(checklist).to have_progress("1 of 3 complete")

    sign_in(admin)
    reports_page.visit_report("lovelace_onboarding")
    expect(page).to have_css("tr", normalize_ws: true, text: "Clicked at least one item link 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Clicked all item links 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Completed at least one item 1")
    expect(page).to have_no_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
    reports_page.visit_report("lovelace_onboarding_items")
    expect(page).to have_css("tr", normalize_ws: true, text: "Complete your profile 1 1")
    expect(page).to have_css("tr", normalize_ws: true, text: "Read community guidelines 1 —")
    expect(page).to have_no_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
    page.refresh
    expect(page).to have_css("tr", normalize_ws: true, text: "Complete your profile 1 1")

    visit "/admin/reports/signups?mode=table"
    expect(reports_page).to have_rendered_report("signups")
    expect(page).to have_content(I18n.t("admin_js.admin.dashboard.reports.totals_for_sample"))
  end
end
