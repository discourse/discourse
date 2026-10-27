# frozen_string_literal: true

describe BundleAnalysisController do
  before do
    EmberAssets.stubs(:bundle_analysis_asset).returns("js/bundle-analysis-abc123.digested.json")
    Plugin::JsManager.stubs(:bundle_analysis_assets).returns(
      ["js/plugins/chat_bundle-analysis-def456.digested.json"],
    )
  end

  it "lists the report each build left behind" do
    get "/bundle-analysis.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      "core" => "/assets/js/bundle-analysis-abc123.digested.json",
      "plugins" => ["/assets/js/plugins/chat_bundle-analysis-def456.digested.json"],
    )
  end

  it "says so when a build has not run" do
    EmberAssets.stubs(:bundle_analysis_asset).returns(nil)
    Plugin::JsManager.stubs(:bundle_analysis_assets).returns([])

    get "/bundle-analysis.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq("core" => nil, "plugins" => [])
  end
end
