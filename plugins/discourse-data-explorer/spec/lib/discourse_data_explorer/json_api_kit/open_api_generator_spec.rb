# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::OpenApiGenerator do
  subject(:document) { described_class.new(endpoints:).document }

  let(:endpoints) do
    [
      {
        path: "/data-explorer/api/queries",
        controller: DiscourseDataExplorer::JsonApiKit::QueriesController,
        create: DiscourseDataExplorer::Query::Create,
      },
    ]
  end
  let(:schemas) { document.dig("components", "schemas") }
  let(:index_operation) { document.dig("paths", "/data-explorer/api/queries", "get") }
  let(:show_operation) { document.dig("paths", "/data-explorer/api/queries/{id}", "get") }
  let(:create_operation) { document.dig("paths", "/data-explorer/api/queries", "post") }

  describe "the document" do
    let(:intro_document) { described_class.new(endpoints:, intro: "# Welcome").document }

    it "targets OpenAPI 3.1" do
      expect(document["openapi"]).to eq("3.1.0")
    end

    it "stamps the advertised API version" do
      expect(document.dig("info", "version")).to eq("2026-07-08")
    end

    it "embeds the intro as the document description" do
      expect(intro_document.dig("info", "description")).to eq("# Welcome")
    end

    it "lists the tags with the resource descriptions" do
      expect(document["tags"]).to include(
        "name" => "Queries",
        "description" =>
          "A saved Data Explorer SQL query: its source, sharing groups, and last-run information.",
      )
    end
  end

  describe "resource schemas" do
    it "declares every resource reachable through relationships" do
      expect(schemas.keys).to include("queries", "users", "groups")
    end

    it "pins the resource object's type" do
      expect(schemas.dig("queries", "properties", "type", "const")).to eq("queries")
    end

    # Attributes are nullable unless a `null: false` declaration exists someday —
    # the live-validation loop proves it (never-run queries answer `ran_at: null`).
    it "maps datetime attributes to nullable date-time strings" do
      expect(schemas.dig("queries", "properties", "attributes", "properties", "ran_at")).to eq(
        "type" => %w[string null],
        "format" => "date-time",
      )
    end

    it "maps boolean attributes" do
      expect(
        schemas.dig("queries", "properties", "attributes", "properties", "hidden", "type"),
      ).to eq(%w[boolean null])
    end

    it "maps array attributes" do
      expect(
        schemas.dig("users", "properties", "attributes", "properties", "usernames", "type"),
      ).to eq(%w[array null])
    end

    it "describes the resource" do
      expect(schemas.dig("queries", "description")).to eq(
        "A saved Data Explorer SQL query: its source, sharing groups, and last-run information.",
      )
    end

    it "carries attribute examples" do
      expect(
        schemas.dig("queries", "properties", "attributes", "properties", "query", "examples"),
      ).to eq(["SELECT id, username FROM users LIMIT 10"])
    end

    it "carries attribute descriptions" do
      expect(
        schemas.dig("queries", "properties", "attributes", "properties", "query", "description"),
      ).to eq("The SQL source of the query.")
    end

    it "rejects undeclared attributes" do
      expect(schemas.dig("queries", "properties", "attributes", "additionalProperties")).to be(
        false,
      )
    end

    it "models to-one relationship linkage as an object" do
      expect(
        schemas.dig(
          "queries",
          "properties",
          "relationships",
          "properties",
          "user",
          "properties",
          "data",
          "type",
        ),
      ).to eq("object")
    end

    it "models to-many relationship linkage as an array" do
      expect(
        schemas.dig(
          "queries",
          "properties",
          "relationships",
          "properties",
          "groups",
          "properties",
          "data",
          "type",
        ),
      ).to eq("array")
    end

    it "declares the error document" do
      expect(schemas.dig("errors", "properties", "errors", "type")).to eq("array")
    end
  end

  describe "the index operation" do
    let(:parameters) { index_operation["parameters"] }
    let(:sort_parameter) { parameters.find { it["name"] == "sort" } }
    let(:include_parameter) { parameters.find { it["name"] == "include" } }

    it "requires the version header" do
      expect(parameters).to include(
        hash_including("name" => "Api-Version", "in" => "header", "required" => true),
      )
    end

    it "is tagged with the resource" do
      expect(index_operation["tags"]).to eq(["Queries"])
    end

    it "carries a summary" do
      expect(index_operation["summary"]).to eq("List queries")
    end

    it "carries an operation id" do
      expect(index_operation["operationId"]).to eq("listQueries")
    end

    it "declares the filter with its value type and description" do
      expect(parameters).to include(
        hash_including(
          "name" => "filter[q]",
          "in" => "query",
          "description" => "Matches the query's name or description.",
          "schema" => hash_including("type" => "string"),
        ),
      )
    end

    it "enumerates the sort keys in both directions" do
      expect(sort_parameter.dig("schema", "items", "enum")).to contain_exactly(
        "name",
        "-name",
        "ran_at",
        "-ran_at",
        "user.username",
        "-user.username",
      )
    end

    it "enumerates the allowed include paths" do
      expect(include_parameter.dig("schema", "items", "enum")).to contain_exactly(
        "user",
        "groups",
        "user.groups",
      )
    end

    it "caps the page size" do
      expect(parameters).to include(
        hash_including(
          "name" => "page[size]",
          "schema" => hash_including("type" => "integer", "maximum" => 100),
        ),
      )
    end

    it "answers with the collection document" do
      expect(
        index_operation.dig(
          "responses",
          "200",
          "content",
          "application/vnd.api+json",
          "schema",
          "properties",
          "data",
          "items",
          "$ref",
        ),
      ).to eq("#/components/schemas/queries")
    end

    it "answers rejections with the error document" do
      expect(
        index_operation.dig(
          "responses",
          "400",
          "content",
          "application/vnd.api+json",
          "schema",
          "$ref",
        ),
      ).to eq("#/components/schemas/errors")
    end
  end

  describe "the show operation" do
    it "carries a summary and operation id" do
      expect(show_operation.values_at("summary", "operationId")).to eq(
        ["Fetch a query", "getQuery"],
      )
    end

    it "requires the id path parameter" do
      expect(show_operation["parameters"]).to include(
        hash_including("name" => "id", "in" => "path", "required" => true),
      )
    end

    it "answers with a single resource document" do
      expect(
        show_operation.dig(
          "responses",
          "200",
          "content",
          "application/vnd.api+json",
          "schema",
          "properties",
          "data",
          "$ref",
        ),
      ).to eq("#/components/schemas/queries")
    end

    it "declares the not-found response" do
      expect(show_operation["responses"]).to have_key("404")
    end
  end

  describe "captured examples" do
    let(:documented) do
      described_class.new(
        endpoints:,
        examples: {
          "listQueries" => {
            "200" => {
              "data" => [],
            },
          },
          "createQuery" => {
            "request" => {
              "data" => {
                "type" => "queries",
              },
            },
            "201" => {
              "data" => {
                "id" => "1",
              },
            },
          },
        },
      ).document
    end
    let(:documented_collection) { documented.dig("paths", "/data-explorer/api/queries", "get") }
    let(:documented_create) { documented.dig("paths", "/data-explorer/api/queries", "post") }

    it "embeds response examples on their operations" do
      expect(
        documented_collection.dig(
          "responses",
          "200",
          "content",
          "application/vnd.api+json",
          "example",
        ),
      ).to eq("data" => [])
    end

    it "embeds request examples on the request body" do
      expect(
        documented_create.dig("requestBody", "content", "application/vnd.api+json", "example"),
      ).to eq("data" => { "type" => "queries" })
    end

    it "embeds examples per response status" do
      expect(
        documented_create.dig("responses", "201", "content", "application/vnd.api+json", "example"),
      ).to eq("data" => { "id" => "1" })
    end
  end

  describe "the create operation" do
    let(:request_attributes) do
      create_operation.dig(
        "requestBody",
        "content",
        "application/vnd.api+json",
        "schema",
        "properties",
        "data",
        "properties",
        "attributes",
      )
    end

    it "carries a summary and operation id" do
      expect(create_operation.values_at("summary", "operationId")).to eq(
        ["Create a query", "createQuery"],
      )
    end

    it "derives the writable attributes from the service contract" do
      expect(request_attributes["properties"].keys).to contain_exactly(
        "name",
        "description",
        "query",
      )
    end

    it "derives required attributes from presence validators" do
      expect(request_attributes["required"]).to eq(%w[name])
    end

    it "derives length limits from length validators" do
      expect(request_attributes.dig("properties", "query", "maxLength")).to eq(10_000)
    end

    it "carries the resource's attribute examples" do
      expect(request_attributes.dig("properties", "name", "examples")).to eq(
        ["Top referred topics"],
      )
    end

    it "answers with the created resource" do
      expect(
        create_operation.dig(
          "responses",
          "201",
          "content",
          "application/vnd.api+json",
          "schema",
          "properties",
          "data",
          "$ref",
        ),
      ).to eq("#/components/schemas/queries")
    end

    it "answers validation failures with the error document" do
      expect(
        create_operation.dig(
          "responses",
          "422",
          "content",
          "application/vnd.api+json",
          "schema",
          "$ref",
        ),
      ).to eq("#/components/schemas/errors")
    end
  end
end
