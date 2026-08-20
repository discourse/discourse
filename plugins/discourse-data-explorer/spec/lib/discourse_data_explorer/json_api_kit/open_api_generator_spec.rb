# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::OpenApiGenerator do
  subject(:document) { described_class.new.document }

  let(:schemas) { document.dig("components", "schemas") }
  let(:index_operation) { document.dig("paths", "/data-explorer/api/queries", "get") }
  let(:show_operation) { document.dig("paths", "/data-explorer/api/queries/{id}", "get") }
  let(:create_operation) { document.dig("paths", "/data-explorer/api/queries", "post") }

  describe "the document" do
    let(:intro_document) { described_class.new(intro: "# Welcome").document }

    it "targets OpenAPI 3.1" do
      expect(document["openapi"]).to eq("3.1.0")
    end

    it "declares the API key credentials as security schemes" do
      expect(document.dig("components", "securitySchemes")).to eq(
        "ApiKey" => {
          "type" => "apiKey",
          "in" => "header",
          "name" => "Api-Key",
        },
        "ApiUsername" => {
          "type" => "apiKey",
          "in" => "header",
          "name" => "Api-Username",
        },
      )
    end

    # Both headers, so one requirement listing both (AND, per OpenAPI).
    it "requires both credentials on every operation" do
      expect(document["security"]).to eq([{ "ApiKey" => [], "ApiUsername" => [] }])
    end

    it "stamps the advertised API version" do
      expect(document.dig("info", "version")).to eq("2026-07-08")
    end

    it "opens the document description with the intro" do
      expect(intro_document.dig("info", "description")).to start_with("# Welcome")
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

    # OpenAPI reserves the `security` scopes array for OAuth2, so the API key
    # scope that permits this operation is documented as an extension.
    it "names the API key scope that permits it" do
      expect(index_operation["x-api-scope"]).to eq("queries:read")
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

    it "enumerates the allowed include paths, plugin namespaces included" do
      expect(include_parameter.dig("schema", "items", "enum")).to contain_exactly(
        "user",
        "groups",
        "user.groups",
        "run-stats",
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

  # The run-stats plugin is registered for real at boot (docs/plugins-design.md,
  # docs/api-docs-generation.md §8) — the generator documents plugin contributions
  # from the same live registry state the runtime serves.
  describe "plugin contributions" do
    let(:parameters) { index_operation["parameters"] }
    let(:run_stats_attribute) do
      schemas.dig("run-stats", "properties", "attributes", "properties", "stale")
    end
    let(:run_stats_relationship) do
      schemas.dig("queries", "properties", "relationships", "properties", "run-stats")
    end

    it "declares the plugin resource schema with its typed attribute" do
      expect(run_stats_attribute).to eq(
        "type" => %w[boolean null],
        "description" => "Whether the query has never been run.",
        "examples" => [false],
      )
    end

    it "links the extended resource to the plugin type" do
      expect(run_stats_relationship.dig("properties", "data", "properties", "type", "const")).to eq(
        "run-stats",
      )
    end

    it "describes the contributed relationship" do
      expect(run_stats_relationship["description"]).to eq(
        "Run statistics the run-stats plugin attaches to the query.",
      )
    end

    it "declares the namespaced filter with its value type and description" do
      expect(parameters).to include(
        hash_including(
          "name" => "filter[run-stats.stale]",
          "in" => "query",
          "description" => "Whether the query has never been run.",
          "schema" => hash_including("type" => "boolean"),
        ),
      )
    end

    it "offers the namespace as an include path" do
      include_parameter = parameters.find { it["name"] == "include" }
      expect(include_parameter.dig("schema", "items", "enum")).to include("run-stats")
    end

    it "offers a sparse fieldset for the plugin type" do
      fields_parameter = parameters.find { it["name"] == "fields[run-stats]" }
      expect(fields_parameter.dig("schema", "items", "enum")).to eq(["stale"])
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

  describe "the changelog" do
    it "derives the machine-readable changelog from the registry, newest first" do
      expect(document["x-changelog"].first).to eq(
        "version" => "2026-07-08",
        "changes" => [
          {
            "description" =>
              "The `last_run_at` attribute of the queries resource is renamed to `ran_at`.",
          },
          { "description" => "The `search` filter of the queries resource is renamed to `q`." },
          {
            "description" =>
              "The `username` sort of the queries resource is renamed to `user.username`.",
          },
        ],
      )
    end

    # One chronological list — defaults resolve one date against every timeline —
    # with foreign entries labeled by their owning component.
    it "labels plugin-owned changes with their component" do
      run_stats_entry = document["x-changelog"].find { it["version"] == "2026-06-20" }
      expect(run_stats_entry["changes"]).to eq(
        [
          {
            "description" => "Renames the run-stats `outdated` attribute to `stale`.",
            "component" => "run-stats",
          },
        ],
      )
    end

    it "appends the changelog to the document description" do
      expect(document.dig("info", "description")).to include("# Changelog", "## 2026-06-15")
    end

    it "prefixes plugin entries with their namespace in the markdown changelog" do
      expect(document.dig("info", "description")).to include(
        "- `run-stats`: Renames the run-stats `outdated` attribute to `stale`.",
      )
    end
  end

  describe "deprecated operations" do
    around do |example|
      DiscourseDataExplorer::JsonApiKit::QueryResource.deprecate(
        :index,
        on: "2026-07-01",
        link: "https://example.com/dep",
      )
      example.run
    ensure
      DiscourseDataExplorer::JsonApiKit::QueryResource.deprecated_actions.delete(:index)
    end

    it "marks the operation as deprecated" do
      expect(index_operation["deprecated"]).to be(true)
    end

    it "leaves other operations alone" do
      expect(show_operation).not_to have_key("deprecated")
    end
  end

  describe "removed operations" do
    let(:removal_change) do
      Class.new(DiscourseDataExplorer::JsonApiKit::VersionChange) do
        version "2026-07-08"
        description "The single-query endpoint is removed."

        removed_endpoint controller: "discourse_data_explorer/json_api_kit/queries", action: :show
      end
    end
    let(:generator) { described_class.new }

    around do |example|
      DiscourseDataExplorer::JsonApiKit.api_versions.register(removal_change)
      example.run
    ensure
      DiscourseDataExplorer::JsonApiKit.api_versions.unregister(removal_change)
    end

    it "drops the operation from the latest document" do
      expect(generator.document.dig("paths", "/data-explorer/api/queries/{id}")).to be_nil
    end

    it "keeps the operation, marked deprecated, for pins from before the removal" do
      expect(
        generator.document_at("2026-06-15").dig(
          "paths",
          "/data-explorer/api/queries/{id}",
          "get",
          "deprecated",
        ),
      ).to be(true)
    end
  end

  describe "#document_at" do
    subject(:versioned) { generator.document_at(version) }

    let(:generator) do
      described_class.new(
        examples: {
          "listQueries" => {
            "200" => {
              "data" => [
                { "type" => "queries", "id" => "1", "attributes" => { "query" => "SELECT 1" } },
              ],
              "included" => [
                {
                  "type" => "users",
                  "id" => "1",
                  "attributes" => {
                    "usernames" => ["query_master"],
                  },
                },
              ],
            },
          },
        },
      )
    end
    let(:versioned_attributes) do
      versioned.dig("components", "schemas", "queries", "properties", "attributes", "properties")
    end
    let(:versioned_parameters) do
      versioned.dig("paths", "/data-explorer/api/queries", "get", "parameters")
    end
    let(:versioned_example) do
      versioned.dig(
        "paths",
        "/data-explorer/api/queries",
        "get",
        "responses",
        "200",
        "content",
        "application/vnd.api+json",
        "example",
      )
    end

    context "when pinned before every change" do
      let(:version) { "2026-05-01" }

      it "stamps the pinned version" do
        expect(versioned.dig("info", "version")).to eq("2026-05-01")
      end

      it "renames attribute schemas back" do
        expect(versioned_attributes).to have_key("sql")
      end

      it "applies the declared old type and down-converts the example" do
        expect(
          versioned.dig(
            "components",
            "schemas",
            "users",
            "properties",
            "attributes",
            "properties",
            "username",
          ),
        ).to eq("type" => %w[string null], "examples" => ["query_master"])
      end

      it "renames the fieldset enums back" do
        expect(
          versioned_parameters
            .find { it["name"] == "fields[queries]" }
            .dig("schema", "items", "enum"),
        ).to include("sql")
      end

      it "renames the filter parameter back" do
        expect(versioned_parameters.map { it["name"] }).to include("filter[search]")
      end

      it "renames the sort keys back" do
        expect(
          versioned_parameters.find { it["name"] == "sort" }.dig("schema", "items", "enum"),
        ).to include("-last_run_at", "username")
      end

      it "renames the request-body attributes back" do
        expect(
          versioned.dig(
            "paths",
            "/data-explorer/api/queries",
            "post",
            "requestBody",
            "content",
            "application/vnd.api+json",
            "schema",
            "properties",
            "data",
            "properties",
            "attributes",
            "properties",
          ),
        ).to have_key("sql")
      end

      it "down-migrates the captured examples" do
        expect(versioned_example.dig("data", 0, "attributes")).to eq("sql" => "SELECT 1")
      end

      it "down-converts included resources in captured examples" do
        expect(versioned_example.dig("included", 0, "attributes")).to eq(
          "username" => "query_master",
        )
      end
    end

    context "when pinned at the current version" do
      let(:version) { "2026-07-08" }

      it "matches the latest document apart from nothing" do
        expect(versioned).to eq(generator.document)
      end
    end

    # The versioned document is the no-override contract: every component
    # resolved at the pin against its own timeline — exactly what a client
    # sending only `Api-Version: <pin>` receives (docs/api-docs-generation.md §8).
    context "when pinned before the plugin's change" do
      let(:version) { "2026-05-01" }
      let(:versioned_plugin_attributes) do
        versioned.dig(
          "components",
          "schemas",
          "run-stats",
          "properties",
          "attributes",
          "properties",
        )
      end

      it "renames the plugin attribute schema back" do
        expect(versioned_plugin_attributes).to have_key("outdated")
      end

      it "renames the namespaced filter parameter back" do
        expect(versioned_parameters.map { it["name"] }).to include("filter[run-stats.outdated]")
      end

      it "renames the plugin fieldset enum back" do
        expect(
          versioned_parameters
            .find { it["name"] == "fields[run-stats]" }
            .dig("schema", "items", "enum"),
        ).to eq(["outdated"])
      end
    end

    context "when pinned past the plugin's change" do
      let(:version) { "2026-07-01" }

      it "keeps the plugin's latest shape" do
        expect(
          versioned.dig(
            "components",
            "schemas",
            "run-stats",
            "properties",
            "attributes",
            "properties",
          ),
        ).to have_key("stale")
      end
    end
  end

  # The global docs structure (docs/api-docs-generation.md §8): the core
  # document carries only what every site serves; each plugin gets its own
  # document — an ownership projection over the same declarations.
  describe "the core-scoped document" do
    subject(:core_document) { described_class.new(scope: :core).document }

    let(:core_index_parameters) do
      core_document.dig("paths", "/data-explorer/api/queries", "get", "parameters")
    end

    it "excludes plugin resource schemas" do
      expect(core_document.dig("components", "schemas").keys).not_to include("run-stats")
    end

    it "excludes the contributed relationship" do
      expect(
        core_document.dig(
          "components",
          "schemas",
          "queries",
          "properties",
          "relationships",
          "properties",
        ),
      ).not_to have_key("run-stats")
    end

    it "excludes the namespaced filter" do
      expect(core_index_parameters.map { it["name"] }).not_to include("filter[run-stats.stale]")
    end

    it "excludes the namespace from the include enum" do
      include_parameter = core_index_parameters.find { it["name"] == "include" }
      expect(include_parameter.dig("schema", "items", "enum")).not_to include("run-stats")
    end

    it "keeps the changelog core-only" do
      expect(core_document["x-changelog"].map { it["version"] }).not_to include("2026-06-20")
    end
  end

  describe "#document_for" do
    subject(:plugin_document) { described_class.new.document_for("run-stats") }

    let(:fragment) { plugin_document.dig("paths", "/data-explorer/api/queries", "get") }
    let(:parameter_names) { fragment["parameters"].map { it["name"] } }

    it "titles the document after the plugin" do
      expect(plugin_document.dig("info", "title")).to eq("Discourse JSON:API — run-stats plugin")
    end

    it "advertises the plugin's own current version" do
      expect(plugin_document.dig("info", "version")).to eq("2026-06-20")
    end

    it "explains the override pinning ritual" do
      expect(plugin_document.dig("info", "description")).to include("run-stats=2026-06-20")
    end

    it "carries only the plugin's changelog" do
      expect(plugin_document["x-changelog"]).to eq(
        [
          {
            "version" => "2026-06-20",
            "changes" => [
              { "description" => "Renames the run-stats `outdated` attribute to `stale`." },
            ],
          },
        ],
      )
    end

    it "declares only the plugin's resource schemas" do
      expect(plugin_document.dig("components", "schemas").keys).to eq(["run-stats"])
    end

    it "documents the touched endpoint as a contributions fragment" do
      expect(fragment["summary"]).to eq("List queries — run-stats contributions")
    end

    # Distinct from the core operation's id: captured examples are keyed by
    # operationId, and the fragment's exchange is its own.
    it "carries a distinct operation id" do
      expect(fragment["operationId"]).to eq("listQueriesRunStats")
    end

    it "lists only the plugin's contributed parameters" do
      expect(parameter_names).to contain_exactly(
        "Api-Version",
        "filter[run-stats.stale]",
        "include",
        "fields[run-stats]",
      )
    end

    it "offers only the plugin's namespace in the include enum" do
      include_parameter = fragment["parameters"].find { it["name"] == "include" }
      expect(include_parameter.dig("schema", "items", "enum")).to eq(["run-stats"])
    end

    it "shows what the plugin adds to the response document" do
      expect(
        fragment.dig(
          "responses",
          "200",
          "content",
          "application/vnd.api+json",
          "schema",
          "properties",
          "included",
          "items",
          "$ref",
        ),
      ).to eq("#/components/schemas/run-stats")
    end

    it "describes the contributed relationship" do
      expect(fragment["description"]).to include(
        "Run statistics the run-stats plugin attaches to the query.",
      )
    end

    context "with a captured example for the fragment" do
      subject(:plugin_document) do
        described_class.new(
          examples: {
            "listQueriesRunStats" => {
              "200" => {
                "data" => [],
                "included" => [
                  { "type" => "run-stats", "id" => "1", "attributes" => { "stale" => true } },
                ],
              },
            },
          },
        ).document_for("run-stats")
      end

      it "embeds the example on the fragment" do
        expect(
          fragment.dig(
            "responses",
            "200",
            "content",
            "application/vnd.api+json",
            "example",
            "included",
            0,
            "attributes",
          ),
        ).to eq("stale" => true)
      end
    end

    # The plugin document versions on ITS OWN timeline — the picker on its docs
    # page offers its own dates, downgraded through its own gap only.
    context "when pinned before the plugin's change" do
      subject(:plugin_document) do
        described_class.new(
          examples: {
            "listQueriesRunStats" => {
              "200" => {
                "data" => [],
                "included" => [
                  { "type" => "run-stats", "id" => "1", "attributes" => { "stale" => true } },
                ],
              },
            },
          },
        ).document_for("run-stats", at: "2026-05-01")
      end

      let(:versioned_plugin_attributes) do
        plugin_document.dig(
          "components",
          "schemas",
          "run-stats",
          "properties",
          "attributes",
          "properties",
        )
      end

      it "stamps the pinned version" do
        expect(plugin_document.dig("info", "version")).to eq("2026-05-01")
      end

      it "renames the schema attribute back" do
        expect(versioned_plugin_attributes).to have_key("outdated")
      end

      it "renames the namespaced filter parameter back" do
        expect(parameter_names).to include("filter[run-stats.outdated]")
      end

      it "renames the fieldset enum back" do
        fields = fragment["parameters"].find { it["name"] == "fields[run-stats]" }
        expect(fields.dig("schema", "items", "enum")).to eq(["outdated"])
      end

      it "down-migrates the captured example" do
        expect(
          fragment.dig(
            "responses",
            "200",
            "content",
            "application/vnd.api+json",
            "example",
            "included",
            0,
            "attributes",
          ),
        ).to eq("outdated" => true)
      end

      it "keeps the full changelog (history, not contract)" do
        expect(plugin_document["x-changelog"].map { it["version"] }).to include("2026-06-20")
      end
    end
  end

  describe "captured examples" do
    let(:documented) do
      described_class.new(
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

    it "names its own API key scope" do
      expect(create_operation["x-api-scope"]).to eq("queries:create")
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
