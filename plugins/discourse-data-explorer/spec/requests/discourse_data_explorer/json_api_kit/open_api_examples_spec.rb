# frozen_string_literal: true

require "json_schemer"

# Live, schema-validated exchanges for every documented operation — and, with
# CAPTURE_API_EXAMPLES=1, the recorder that writes them into
# openapi-examples.json for the generator to embed as the document's examples.
# Captures are deterministic: time is frozen, fabricated values are explicit,
# ids are remapped per type in first-seen order, and cursors become stable
# placeholders (they are opaque by contract).
RSpec.describe "JSON:API Kit OpenAPI examples" do
  CONTENT_TYPE = "application/vnd.api+json"

  fab!(:author) { Fabricate(:admin, username: "query_master") }
  fab!(:sql_writers) { Fabricate(:group, name: "sql_writers") }
  fab!(:ran_query) do
    Fabricate(
      :query,
      user: author,
      name: "Top referred topics",
      description: "Topics most often linked from other topics.",
      sql: "SELECT id, title FROM topics ORDER BY like_count DESC LIMIT 10",
      hidden: false,
      last_run_at: Time.utc(2026, 7, 1, 10, 0),
      created_at: Time.utc(2026, 6, 20, 9, 0),
      updated_at: Time.utc(2026, 6, 20, 9, 0),
    )
  end
  fab!(:never_run_query) do
    Fabricate(
      :query,
      user: author,
      name: "Inactive staff",
      sql: "SELECT id, username FROM users WHERE admin",
      hidden: false,
      last_run_at: nil,
      created_at: Time.utc(2026, 6, 21, 9, 0),
      updated_at: Time.utc(2026, 6, 21, 9, 0),
    )
  end
  fab!(:query_group) do
    DiscourseDataExplorer::QueryGroup.create!(query: ran_query, group: sql_writers)
  end

  let(:document) { DiscourseDataExplorer::JsonApiKit.openapi_document }
  let(:parsed_document) { JSON.parse(response.body) }

  before do
    SiteSetting.data_explorer_enabled = true
    freeze_time Time.utc(2026, 7, 8, 12, 0)
    sign_in(author)
  end

  def api_headers
    { "Accept" => CONTENT_TYPE, "Api-Version" => "2026-07-08" }
  end

  def schema_for(method, path, status)
    schema =
      document.dig("paths", path, method, "responses", status, "content", CONTENT_TYPE, "schema")
    JSONSchemer.schema(schema.merge("components" => document["components"]))
  end

  def create_request_body
    {
      data: {
        type: "queries",
        attributes: {
          name: "Category health",
          description: "Topics per category over the last 30 days.",
          query: "SELECT category_id, COUNT(*) FROM topics GROUP BY 1",
        },
      },
    }
  end

  context "when listing queries" do
    before do
      get "/data-explorer/api/queries",
          params: {
            include: "user,groups,user.groups",
          },
          headers: api_headers
    end

    it "answers with a schema-valid document" do
      expect(
        schema_for("get", "/data-explorer/api/queries", "200").validate(parsed_document).to_a,
      ).to eq([])
    end
  end

  context "when fetching a query" do
    before { get "/data-explorer/api/queries/#{ran_query.id}", headers: api_headers }

    it "answers with a schema-valid document" do
      expect(
        schema_for("get", "/data-explorer/api/queries/{id}", "200").validate(parsed_document).to_a,
      ).to eq([])
    end
  end

  context "when creating a query" do
    before do
      post "/data-explorer/api/queries",
           params: create_request_body,
           as: :json,
           headers: {
             "Api-Version" => "2026-07-08",
           }
    end

    it "answers with a schema-valid document" do
      expect(
        schema_for("post", "/data-explorer/api/queries", "201").validate(parsed_document).to_a,
      ).to eq([])
    end
  end

  context "when the created query is invalid" do
    before do
      post "/data-explorer/api/queries",
           params: create_request_body.deep_merge(data: { attributes: { name: "" } }),
           as: :json,
           headers: {
             "Api-Version" => "2026-07-08",
           }
    end

    it "answers with a schema-valid error document" do
      expect(
        schema_for("post", "/data-explorer/api/queries", "422").validate(parsed_document).to_a,
      ).to eq([])
    end
  end

  it "records the examples", if: ENV["CAPTURE_API_EXAMPLES"] do
    File.write(examples_path, JSON.pretty_generate(captured_examples) + "\n")
    expect(JSON.parse(File.read(examples_path))).to eq(captured_examples)
  end

  private

  def examples_path
    Rails.root.join("plugins/discourse-data-explorer/openapi-examples.json")
  end

  def captured_examples
    @captured_examples ||= {
      "listQueries" => {
        "200" => capture_list,
      },
      "getQuery" => {
        "200" => capture_show,
      },
      "createQuery" => capture_create,
    }
  end

  def capture_list
    get "/data-explorer/api/queries",
        params: {
          include: "user,groups,user.groups",
        },
        headers: api_headers
    normalize(JSON.parse(response.body))
  end

  def capture_show
    get "/data-explorer/api/queries/#{ran_query.id}", headers: api_headers
    normalize(JSON.parse(response.body))
  end

  def capture_create
    post "/data-explorer/api/queries",
         params: create_request_body,
         as: :json,
         headers: {
           "Api-Version" => "2026-07-08",
         }
    created = normalize(JSON.parse(response.body))

    post "/data-explorer/api/queries",
         params: create_request_body.deep_merge(data: { attributes: { name: "" } }),
         as: :json,
         headers: {
           "Api-Version" => "2026-07-08",
         }
    {
      "request" => create_request_body.deep_stringify_keys,
      "201" => created,
      "422" => JSON.parse(response.body),
    }
  end

  # Ids remap per type in first-seen order; opaque cursors become stable
  # placeholders — the two sources of run-to-run churn.
  def normalize(node, ids = default_id_map, cursors = default_cursor_map)
    case node
    when Hash
      node["id"] = ids[node["type"]][node["id"]] if node["type"].is_a?(String) &&
        node["id"].is_a?(String)
      node["page"]["cursor"] = cursors[node.dig("page", "cursor")] if node.dig("page", "cursor")
      node.each_value { normalize(it, ids, cursors) }
    when Array
      node.each { normalize(it, ids, cursors) }
    end
    node
  end

  def default_id_map
    Hash.new { |types, type| types[type] = Hash.new { |map, id| map[id] = (map.size + 1).to_s } }
  end

  def default_cursor_map
    Hash.new { |map, cursor| map[cursor] = "opaque-cursor-#{map.size + 1}" }
  end
end
