# frozen_string_literal: true

RSpec.describe "data_explorer:json_api_docs" do
  let(:plugin_root) { Rails.root.join("plugins/discourse-data-explorer") }

  before { Rake::Task["data_explorer:json_api_docs"].actions.first.call }

  it "writes the core OpenAPI document" do
    expect(JSON.parse(plugin_root.join("openapi-jsonapi.json").read)).to eq(
      DiscourseDataExplorer::JsonApiKit.openapi_document(scope: :core),
    )
  end

  it "writes one document per registered plugin" do
    expect(JSON.parse(plugin_root.join("openapi-jsonapi-plugin-run-stats.json").read)).to eq(
      DiscourseDataExplorer::JsonApiKit.openapi_document_for("run-stats"),
    )
  end

  it "writes one document per plugin version" do
    expect(
      JSON.parse(plugin_root.join("openapi-jsonapi-plugin-run-stats-2026-05-01.json").read),
    ).to eq(DiscourseDataExplorer::JsonApiKit.openapi_document_for("run-stats", at: "2026-05-01"))
  end

  it "writes the manifest with the core versions and the plugins' own versions" do
    expect(JSON.parse(plugin_root.join("openapi-versions.json").read)).to eq(
      "versions" => DiscourseDataExplorer::JsonApiKit.openapi_versions,
      "plugins" => [{ "namespace" => "run-stats", "versions" => %w[2026-06-20 2026-05-01] }],
    )
  end
end
