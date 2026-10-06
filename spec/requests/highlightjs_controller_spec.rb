# frozen_string_literal: true

RSpec.describe HighlightJsController do
  fab!(:user)

  it "works via the site URL" do
    get HighlightJs.path
    expect(response.status).to eq(200)
    expect(response.body).to include("export default function")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end

  it "does not include a username in the cacheable response" do
    sign_in(user)

    get HighlightJs.path

    expect(response.status).to eq(200)
    expect(response.headers["X-Discourse-Username"]).to be_nil
  end

  it "works via a CDN" do
    cdn = "https://original-app-cdn.example.com"
    set_cdn_url cdn

    get "#{cdn}#{HighlightJs.path}"
    expect(response.status).to eq(200)
    expect(response.body).to include("export default function")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end

  it "works via a CDN when site has cors configuration" do
    cdn = "https://original-app-cdn.example.com"
    set_cdn_url cdn

    global_setting :enable_cors, true
    SiteSetting.cors_origins = "https://example.com"

    get "#{cdn}#{HighlightJs.path}"
    expect(response.status).to eq(200)
    expect(response.body).to include("export default function")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end
end
