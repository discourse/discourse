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
    JSON.parse(response.body)
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
    JSON.parse(response.body)
  end

  describe "Trace A — response down" do
    it "serves the old shape to a client pinned before the rename" do
      doc = get_queries(headers: { "Discourse-Api-Version" => "2026-05-20" })

      attributes = doc["data"].first["attributes"]
      expect(response.status).to eq(200)
      expect(attributes["sql"]).to eq(query.sql)
      expect(attributes).not_to have_key("query")
      expect(response.headers["Discourse-Api-Version"]).to eq(initial_version)
    end

    it "serves the latest shape to a current client" do
      doc = get_queries(headers: { "Discourse-Api-Version" => "2026-07-01" })

      attributes = doc["data"].first["attributes"]
      expect(response.status).to eq(200)
      expect(attributes["query"]).to eq(query.sql)
      expect(attributes).not_to have_key("sql")
      expect(response.headers["Discourse-Api-Version"]).to eq(current_version)
    end
  end

  describe "Trace B — query params up (sparse fieldsets)" do
    it "honors an old client's fieldset naming the old attribute" do
      doc =
        get_queries(
          headers: {
            "Discourse-Api-Version" => "2026-05-20",
          },
          params: {
            fields: {
              queries: "name,sql",
            },
          },
        )

      expect(doc["data"].first["attributes"].keys).to contain_exactly("name", "sql")
    end
  end

  describe "Trace C — request up (POST create)" do
    it "accepts an old client's body and persists through the latest contract" do
      doc = post_query({ name: "Slow topics", sql: "SELECT 2" }, version: "2026-05-20")

      expect(response.status).to eq(201)
      expect(DiscourseDataExplorer::Query.last.sql).to eq("SELECT 2")
      expect(doc.dig("data", "attributes", "sql")).to eq("SELECT 2")
    end

    it "accepts a current client's body unchanged" do
      doc = post_query({ name: "Fast topics", query: "SELECT 3" }, version: "2026-07-01")

      expect(response.status).to eq(201)
      expect(DiscourseDataExplorer::Query.last.sql).to eq("SELECT 3")
      expect(doc.dig("data", "attributes", "query")).to eq("SELECT 3")
    end
  end

  describe "Trace D — validation errors down" do
    it "keeps the pointer intact for an attribute the rename does not touch" do
      doc = post_query({ name: "", sql: "SELECT 2" }, version: "2026-05-20")

      expect(response.status).to eq(422)
      expect(doc["errors"].first.dig("source", "pointer")).to eq("/data/attributes/name")
    end
  end

  describe "Trace E — header mechanics" do
    it "rejects a missing version header with a body teaching the current version" do
      get_queries

      expect(response.status).to eq(400)
      expect(response.body).to include(current_version)
    end

    it "rejects a malformed version" do
      get_queries(headers: { "Discourse-Api-Version" => "garbage" })

      expect(response.status).to eq(400)
    end

    it "rejects a version predating the first API version" do
      get_queries(headers: { "Discourse-Api-Version" => "2026-04-01" })

      expect(response.status).to eq(400)
    end

    it "rejects a future version" do
      get_queries(headers: { "Discourse-Api-Version" => "2027-01-01" })

      expect(response.status).to eq(400)
    end
  end
end
