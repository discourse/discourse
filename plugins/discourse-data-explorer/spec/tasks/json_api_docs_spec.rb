# frozen_string_literal: true

RSpec.describe "data_explorer:json_api_docs" do
  subject(:generate) { Rake::Task["data_explorer:json_api_docs"].actions.first.call }

  let(:output_path) { Rails.root.join("plugins/discourse-data-explorer/openapi-jsonapi.json") }

  it "writes the OpenAPI document" do
    generate
    expect(JSON.parse(File.read(output_path))).to eq(
      DiscourseDataExplorer::JsonApiKit.openapi_document,
    )
  end
end
