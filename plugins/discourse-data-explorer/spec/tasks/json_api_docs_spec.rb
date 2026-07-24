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

  it "writes the manifest with the core versions and the plugins" do
    expect(JSON.parse(plugin_root.join("openapi-versions.json").read)).to eq(
      "versions" => DiscourseDataExplorer::JsonApiKit.openapi_versions,
      "plugins" => ["run-stats"],
    )
  end
end
