# frozen_string_literal: true

# Executable acceptance script for docs/versioning-design.md §1 — the sql→query trace.
# Deliberately written AHEAD of the pipeline (design doc §2): examples go green
# increment by increment — response-down (②) turns Traces A/E green, request-up (③)
# turns B and the old-client half of C green, error migration (④) extends D. The
# latest-client examples pass from day one: they pin the current contract.
RSpec.describe "JSON:API Kit versioning" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, user: admin, hidden: false, sql: "SELECT 42 AS answer") }

  let(:initial_version) { "2026-05-01" }
  let(:current_version) { "2026-06-15" }
  let(:parsed_document) { JSON.parse(response.body) }
  let(:parsed_attributes) { parsed_document["data"].first["attributes"] }

  before do
    SiteSetting.data_explorer_enabled = true
    freeze_time Time.zone.parse("2026-07-08 12:00")
    sign_in(admin)
  end

  def get_queries(headers: {}, params: {})
    get "/data-explorer/api/queries",
        params: params,
        headers: {
          "Accept" => "application/vnd.api+json",
          **headers,
        }
  end

  def post_query(attributes, version:)
    post "/data-explorer/api/queries",
         params: {
           data: {
             type: "queries",
             attributes: attributes,
           },
         },
         as: :json,
         headers: {
           "Discourse-Api-Version" => version,
         }
  end

  describe "Trace A — response down" do
    context "when the client is pinned before the rename" do
      let(:headers) { { "Discourse-Api-Version" => "2026-05-20" } }

      before { get_queries(headers:) }

      it "serves the old shape and echoes the resolved version" do
        expect(response.status).to eq(200)
        expect(parsed_attributes["sql"]).to eq(query.sql)
        expect(parsed_attributes).not_to have_key("query")
        expect(response.headers["Discourse-Api-Version"]).to eq(initial_version)
      end
    end

    context "when the client is pinned after the rename" do
      let(:headers) { { "Discourse-Api-Version" => "2026-07-01" } }

      before { get_queries(headers:) }

      it "serves the latest shape and echoes the resolved version" do
        expect(response.status).to eq(200)
        expect(parsed_attributes["query"]).to eq(query.sql)
        expect(parsed_attributes).not_to have_key("sql")
        expect(response.headers["Discourse-Api-Version"]).to eq(current_version)
      end
    end
  end

  describe "Trace B — query params up (sparse fieldsets)" do
    context "when an old client's fieldset names the old attribute" do
      let(:headers) { { "Discourse-Api-Version" => "2026-05-20" } }

      before { get_queries(headers:, params: { fields: { queries: "name,sql" } }) }

      it "returns exactly the requested fields, with their real values" do
        expect(parsed_attributes.keys).to contain_exactly("name", "sql")
        expect(parsed_attributes["sql"]).to eq(query.sql)
      end
    end
  end

  describe "Trace C — request up (POST create)" do
    context "when an old client posts the old shape" do
      before { post_query({ name: "Slow topics", sql: "SELECT 2" }, version: "2026-05-20") }

      it "persists through the latest contract and answers in the old shape" do
        expect(response.status).to eq(201)
        expect(DiscourseDataExplorer::Query.last.sql).to eq("SELECT 2")
        expect(parsed_document.dig("data", "attributes", "sql")).to eq("SELECT 2")
      end
    end

    context "when a current client posts the latest shape" do
      before { post_query({ name: "Fast topics", query: "SELECT 3" }, version: "2026-07-01") }

      it "persists and answers in the latest shape" do
        expect(response.status).to eq(201)
        expect(DiscourseDataExplorer::Query.last.sql).to eq("SELECT 3")
        expect(parsed_document.dig("data", "attributes", "query")).to eq("SELECT 3")
      end
    end
  end

  describe "Trace D — validation errors down" do
    let(:too_long_sql) { "SELECT 1 -- #{"x" * 10_000}" }

    context "when the failing attribute is untouched by any rename" do
      before { post_query({ name: "", sql: "SELECT 2" }, version: "2026-05-20") }

      it "keeps the latest pointer" do
        expect(response.status).to eq(422)
        expect(parsed_document["errors"].first.dig("source", "pointer")).to eq(
          "/data/attributes/name",
        )
      end
    end

    context "when an old client fails validation on the renamed attribute" do
      before { post_query({ name: "Big", sql: too_long_sql }, version: "2026-05-20") }

      it "rewrites the pointer to the name the client used" do
        expect(response.status).to eq(422)
        expect(parsed_document["errors"].first.dig("source", "pointer")).to eq(
          "/data/attributes/sql",
        )
      end
    end

    context "when a current client fails validation on the renamed attribute" do
      before { post_query({ name: "Big", query: too_long_sql }, version: "2026-07-01") }

      it "keeps the latest pointer" do
        expect(response.status).to eq(422)
        expect(parsed_document["errors"].first.dig("source", "pointer")).to eq(
          "/data/attributes/query",
        )
      end
    end
  end

  describe "Trace E — header mechanics" do
    context "without a version header" do
      before { get_queries }

      it "rejects the request with a body teaching the current version" do
        expect(response.status).to eq(400)
        expect(response.body).to include(current_version)
      end
    end

    context "with a malformed version" do
      let(:headers) { { "Discourse-Api-Version" => "garbage" } }

      before { get_queries(headers:) }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end

    context "with a version predating the first API version" do
      let(:headers) { { "Discourse-Api-Version" => "2026-04-01" } }

      before { get_queries(headers:) }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end

    context "with a future version" do
      let(:headers) { { "Discourse-Api-Version" => "2027-01-01" } }

      before { get_queries(headers:) }

      it "rejects the request" do
        expect(response.status).to eq(400)
      end
    end
  end
end
