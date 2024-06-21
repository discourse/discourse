# frozen_string_literal: true

describe "Content security policy", type: :system do
  it "can boot the application in strict_dynamic mode" do
    expect(SiteSetting.content_security_policy).to eq(true)

    visit "/"
    expect(page).to have_css("#site-logo")
  end

  it "works for 'public exceptions' like RoutingError" do
    expect(SiteSetting.content_security_policy).to eq(true)
    SiteSetting.bootstrap_error_pages = true

    get "/nonexistent"
    expect(response.headers["Content-Security-Policy"]).to include("'strict-dynamic'")

    visit "/nonexistent"
    expect(page).not_to have_css("body.no-ember")
    expect(page).to have_css("#site-logo")
  end

  it "can boot logster in strict_dynamic mode" do
    expect(SiteSetting.content_security_policy).to eq(true)
    sign_in Fabricate(:admin)

    visit "/logs"
    expect(page).to have_css("#log-table")
  end
end
