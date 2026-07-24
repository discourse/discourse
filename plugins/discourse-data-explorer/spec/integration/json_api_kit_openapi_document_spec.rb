# frozen_string_literal: true

# The committed OpenAPI documents are contract artifacts (like the Kit contract
# baseline): they must match what the declarations generate. When a resource,
# contract, extension, or version change alters the API surface, regenerate with
# `bin/rake data_explorer:json_api_docs` and commit the diff — the diff IS the
# review surface for the docs change. The committed set mirrors the global docs
# structure (docs/api-docs-generation.md §8): the core document plus one
# document per plugin.
RSpec.describe "Data Explorer OpenAPI document freshness" do
  subject(:committed_document) do
    JSON.parse(Rails.root.join("plugins/discourse-data-explorer/openapi-jsonapi.json").read)
  end

  it "matches the core document generated from the current declarations" do
    expect(committed_document).to eq(
      DiscourseDataExplorer::JsonApiKit.openapi_document(scope: :core),
    )
  end

  describe "versioned documents" do
    subject(:stale_versions) do
      DiscourseDataExplorer::JsonApiKit.openapi_versions.reject do |version|
        JSON.parse(
          Rails.root.join("plugins/discourse-data-explorer/openapi-jsonapi-#{version}.json").read,
        ) == DiscourseDataExplorer::JsonApiKit.openapi_document_at(version, scope: :core)
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

    it "keeps the manifest current" do
      expect(committed_manifest).to eq(
        "versions" => DiscourseDataExplorer::JsonApiKit.openapi_versions,
        "plugins" => DiscourseDataExplorer::JsonApiKit.extensions.keys.sort,
      )
    end
  end

  describe "plugin documents" do
    subject(:stale_plugins) do
      DiscourseDataExplorer::JsonApiKit.extensions.keys.sort.reject do |namespace|
        JSON.parse(
          Rails
            .root
            .join("plugins/discourse-data-explorer/openapi-jsonapi-plugin-#{namespace}.json")
            .read,
        ) == DiscourseDataExplorer::JsonApiKit.openapi_document_for(namespace)
      end
    end

    it "keeps every plugin document current" do
      expect(stale_plugins).to eq([])
    end
  end
end
