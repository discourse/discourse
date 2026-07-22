# frozen_string_literal: true

require "json_schemer"

# The drift-proof loop (docs/api-docs-generation.md §7): the OpenAPI document is
# DERIVED from the Kit's declarations, and this spec closes the circle by
# validating LIVE responses against the generated schemas — rswag's virtue,
# pointed at a generated schema instead of a hand-written one. A serializer
# change without its declaration fails here, loudly.
RSpec.describe "JSON:API Kit OpenAPI document" do
  fab!(:admin)
  fab!(:group)
  fab!(:ran_query) do
    Fabricate(:query, user: admin, hidden: false, last_run_at: Time.utc(2026, 7, 1, 10, 0))
  end
  fab!(:never_run_query) { Fabricate(:query, user: admin, hidden: false, last_run_at: nil) }

  let(:current_version) { "2026-07-08" }
  let(:document) do
    DiscourseDataExplorer::JsonApiKit::OpenApiGenerator.new(
      endpoints: [
        {
          path: "/data-explorer/api/queries",
          controller: DiscourseDataExplorer::JsonApiKit::QueriesController,
          create: DiscourseDataExplorer::Query::Create,
        },
      ],
    ).document
  end
  let(:collection_schema) do
    document.dig(
      "paths",
      "/data-explorer/api/queries",
      "get",
      "responses",
      "200",
      "content",
      "application/vnd.api+json",
      "schema",
    )
  end
  let(:collection_schemer) do
    JSONSchemer.schema(collection_schema.merge("components" => document["components"]))
  end
  let(:parsed_document) { JSON.parse(response.body) }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  def get_queries(params: {})
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
          "Api-Version" => current_version,
        }
  end

  context "when fetching the collection" do
    before { get_queries }

    it "matches the generated schema" do
      expect(collection_schemer.validate(parsed_document).to_a).to eq([])
    end
  end

  context "when including related resources" do
    before do
      get_queries(params: { include: "user,groups,user.groups", stats: { total: "count" } })
    end

    it "matches the generated schema" do
      expect(collection_schemer.validate(parsed_document).to_a).to eq([])
    end
  end

  context "when the request is rejected" do
    let(:error_schemer) { JSONSchemer.schema(document.dig("components", "schemas", "errors")) }

    before { get_queries(params: { filter: { nope: "1" } }) }

    it "matches the generated error schema" do
      expect(error_schemer.validate(parsed_document).to_a).to eq([])
    end
  end
end
