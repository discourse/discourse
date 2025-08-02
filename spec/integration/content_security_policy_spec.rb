# frozen_string_literal: true

RSpec.describe "content security policy integration" do
  it "adds the csp headers correctly" do
    Fabricate(:admin) # to avoid 'new installation' screen

    SiteSetting.content_security_policy = false
    get "/"
    expect(response.headers["Content-Security-Policy"]).to eq(nil)

    SiteSetting.content_security_policy = true
    get "/"
    expect(response.headers["Content-Security-Policy"]).to be_present

    expect(response.headers["Content-Security-Policy"]).to match(
      /script-src 'nonce-[^']+' 'strict-dynamic';/,
    )
  end
end
