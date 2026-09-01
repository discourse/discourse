# frozen_string_literal: true

# Publication and support (docs/resource-design.md §9): `internal!` marks an endpoint
# as shaped for our own client. It drops out of the generated documentation and out of
# the versioning contract (nothing to pin), while the framework's other guarantees —
# types, filters, pagination, errors — stay exactly as they are.
RSpec.describe "JSON:API Kit internal endpoints" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, hidden: false) }

  let(:parsed_document) { JSON.parse(response.body) }
  let(:attributes) { parsed_document["data"].first["attributes"] }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(admin)
  end

  def get_internal(headers: {})
    get "/data-explorer/api/internal/queries",
        headers: { "Accept" => "application/vnd.api+json" }.merge(headers)
  end

  it "serves without a version header" do
    get_internal
    expect(response.status).to eq(200)
  end

  it "advertises no version" do
    get_internal
    expect(response.headers["Api-Version"]).to be_nil
  end

  # An old pin means nothing here: there is no promise to keep, so the response is
  # whatever the code currently produces.
  it "ignores a pin and serves the latest shape" do
    get_internal(headers: { "Api-Version" => "2026-05-20" })
    expect(attributes).to have_key("query")
    expect(attributes).not_to have_key("sql")
  end

  it "keeps the framework's other behaviour" do
    get "/data-explorer/api/internal/queries",
        params: {
          filter: {
            nonsense: "1",
          },
        },
        headers: {
          "Accept" => "application/vnd.api+json",
        }
    expect(response.status).to eq(400)
  end

  describe "the published surface" do
    let(:generator) { DiscourseDataExplorer::JsonApiKit::OpenApiGenerator.new }

    # Endpoints come from the route table now, so the internal one is genuinely
    # discoverable and genuinely excluded — not merely absent from a hand-written map.
    it "leaves internal endpoints out of the documentation" do
      expect(generator.document["paths"].keys).to eq(
        %w[/data-explorer/api/queries /data-explorer/api/queries/{id}],
      )
    end
  end

  describe "API key scopes" do
    let(:api_key) { Fabricate(:api_key, user: admin) }
    let(:key_headers) do
      {
        "Accept" => "application/vnd.api+json",
        "HTTP_API_KEY" => api_key.key,
        "HTTP_API_USERNAME" => admin.username,
      }
    end

    it "grants no scope for them" do
      actions =
        DiscourseDataExplorer::JsonApiKit::ApiKeyScopes.mappings.values.flat_map do |scopes|
          scopes.values.flat_map { it[:actions] }
        end
      expect(actions.grep(/internal/)).to eq([])
    end

    # Consequence worth knowing: with no scope covering them, a granular key cannot
    # reach an internal endpoint at all — partial enforcement, for free.
    it "refuses a granular key" do
      ApiKeyScope.create!(api_key_id: api_key.id, resource: "queries", action: "read")
      get "/data-explorer/api/internal/queries", headers: key_headers
      expect(response.status).to eq(403)
    end

    it "still allows an unscoped key" do
      get "/data-explorer/api/internal/queries", headers: key_headers
      expect(response.status).to eq(200)
    end
  end

  # The boundary should be visible in the URL, not only in the docs.
  it "is routed under an internal segment" do
    paths =
      Rails
        .application
        .routes
        .routes
        .select do |route|
          controller = route.defaults[:controller].to_s
          controller.include?("json_api_kit") &&
            "#{controller}_controller".camelize.safe_constantize&.internal?
        end
        .map { it.path.spec.to_s }
    expect(paths).to all(include("/internal/"))
  end

  # The routes file names each endpoint once; the verbs and the `internal/` segment
  # come from the controller's declarations, so the boundary cannot be forgotten.
  describe "route derivation" do
    def recognize(path, method: :get)
      Rails.application.routes.recognize_path(path, method:)
    end

    it "places an internal endpoint under an internal segment" do
      expect(recognize("/data-explorer/api/internal/queries")).to include(
        controller: "discourse_data_explorer/json_api_kit/internal_queries",
        action: "index",
      )
    end

    it "routes the reads the framework implements" do
      expect(recognize("/data-explorer/api/internal/queries/1")).to include(action: "show")
    end

    it "routes a write only where the endpoint implements it" do
      expect(recognize("/data-explorer/api/queries", method: :post)).to include(action: "create")
      expect { recognize("/data-explorer/api/internal/queries", method: :post) }.to raise_error(
        ActionController::RoutingError,
      )
    end

    it "leaves the published paths alone" do
      expect(recognize("/data-explorer/api/queries")).to include(
        controller: "discourse_data_explorer/json_api_kit/queries",
        action: "index",
      )
    end
  end
end
