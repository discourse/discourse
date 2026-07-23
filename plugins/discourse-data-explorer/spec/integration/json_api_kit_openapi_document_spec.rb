# frozen_string_literal: true

# The committed OpenAPI document is a contract artifact (like the Kit contract
# baseline): it must match what the declarations generate. When a resource,
# contract, or version change alters the API surface, regenerate with
# `bin/rake data_explorer:json_api_docs` and commit the diff — the diff IS the
# review surface for the docs change.
RSpec.describe "Data Explorer OpenAPI document freshness" do
  subject(:committed_document) do
    JSON.parse(Rails.root.join("plugins/discourse-data-explorer/openapi-jsonapi.json").read)
  end

  it "matches the document generated from the current declarations" do
    expect(committed_document).to eq(DiscourseDataExplorer::JsonApiKit.openapi_document)
  end
end
