# frozen_string_literal: true

RSpec.describe "message bus integration" do
  it "allows anonymous requests to the messagebus" do
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows authenticated requests to the messagebus" do
    sign_in Fabricate(:user)
    post "/message-bus/poll"
    expect(response.status).to eq(200)
  end

  it "allows custom cors origins" do
    global_setting :enable_cors, true
    SiteSetting.cors_origins = "https://allowed.example.com"

    post "/message-bus/poll"
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)

    post "/message-bus/poll", headers: { origin: "https://allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://allowed.example.com")

    post "/message-bus/poll", headers: { origin: "https://not-allowed.example.com" }
    expect(response.headers["Access-Control-Allow-Origin"]).to eq(Discourse.base_url_no_prefix)
  end

  context "with login_required" do
    before { SiteSetting.login_required = true }

    it "blocks anonymous requests to the messagebus" do
      post "/message-bus/poll"
      expect(response.status).to eq(403)
    end

    it "allows authenticated requests to the messagebus" do
      sign_in Fabricate(:user)
      post "/message-bus/poll"
      expect(response.status).to eq(200)
    end
  end
end
