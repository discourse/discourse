# frozen_string_literal: true

describe "Global notice" do
  it "is persistent by default" do
    SiteSetting.global_notice = "A site announcement"
    visit "/latest"

    expect(page).to have_css(".alert-global-notice", text: "A site announcement")
    expect(page).to have_no_css(".alert-global-notice .close")
  end

  it "remembers a dismissal until the content changes" do
    SiteSetting.global_notice_dismissible = true
    SiteSetting.global_notice = "Announcement Aa"
    visit "/latest"
    find(".alert-global-notice .close").click
    expect(page).to have_no_css(".alert-global-notice")

    page.refresh
    expect(page).to have_no_css(".alert-global-notice")

    SiteSetting.global_notice = "Announcement BB"
    page.refresh
    expect(page).to have_css(".alert-global-notice", text: "Announcement BB")

    find(".alert-global-notice .close").click
    SiteSetting.global_notice_dismissible = false
    page.refresh
    expect(page).to have_css(".alert-global-notice", text: "Announcement BB")
    expect(page).to have_no_css(".alert-global-notice .close")
  end
end
