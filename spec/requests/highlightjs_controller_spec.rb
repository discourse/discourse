# frozen_string_literal: true

RSpec.describe HighlightJsController do
  it "works via the site URL" do
    get HighlightJs.path
    expect(response.status).to eq(200)
    expect(response.body).to include("export default function")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
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
