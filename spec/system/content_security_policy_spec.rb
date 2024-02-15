# frozen_string_literal: true

describe "Content security policy", type: :system do
  it "can boot the application in strict_dynamic mode" do
    expect(SiteSetting.content_security_policy).to eq(true)
    SiteSetting.content_security_policy_strict_dynamic = true

    visit "/"
    expect(page).to have_css("#site-logo")
  end
end
