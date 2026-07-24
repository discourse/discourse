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

  describe "versioned documents" do
    subject(:stale_versions) do
      DiscourseDataExplorer::JsonApiKit.openapi_versions.reject do |version|
        JSON.parse(
          Rails.root.join("plugins/discourse-data-explorer/openapi-jsonapi-#{version}.json").read,
        ) == DiscourseDataExplorer::JsonApiKit.openapi_document_at(version)
      end
    end

    let(:committed_manifest) do
      JSON.parse(Rails.root.join("plugins/discourse-data-explorer/openapi-versions.json").read)
    end

    # Old-version documents change over time by design: every new change
    # deepens their gap. They regenerate with the same rake task.
    it "keeps every versioned document current" do
      expect(stale_versions).to eq([])
    end

    it "keeps the version manifest current" do
      expect(committed_manifest).to eq(DiscourseDataExplorer::JsonApiKit.openapi_versions)
    end
  end
end
