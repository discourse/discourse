# frozen_string_literal: true

# Acceptance script for docs/resource-design.md §8: the Kit plugs into core's API
# key scope system rather than reimplementing it. Scopes gate routes, so the
# mapping is derived per endpoint from the route table and registered through the
# existing plugin API — core's model, matcher and admin UI are untouched.
RSpec.describe "JSON:API Kit API key scopes" do
  fab!(:admin)
  fab!(:query) { Fabricate(:query, hidden: false) }
  # `let`, not `fab!`: the key is only readable on the instance that created it.
  let(:api_key) { Fabricate(:api_key, user: admin) }
  let(:headers) do
    {
      "Accept" => "application/vnd.api+json",
      "Api-Version" => "2026-07-08",
      "HTTP_API_KEY" => api_key.key,
      "HTTP_API_USERNAME" => admin.username,
    }
  end

  before { SiteSetting.data_explorer_enabled = true }

  def scope!(resource, action, allowed_parameters: nil)
    ApiKeyScope.create!(
      api_key_id: api_key.id,
      resource: resource,
      action: action,
      allowed_parameters: allowed_parameters,
    )
  end

  def create_body
    { data: { type: "queries", attributes: { name: "New query", query: "SELECT 1" } } }
  end

  describe "the derived mapping" do
    subject(:mapping) { ApiKeyScope.scope_mappings[:queries] }

    it "registers the resource under its JSON:API type" do
      expect(mapping).to be_present
    end

    it "groups the read actions" do
      expect(mapping.dig(:read, :actions)).to contain_exactly(
        "discourse_data_explorer/json_api_kit/queries#index",
        "discourse_data_explorer/json_api_kit/queries#show",
      )
    end

    it "allows restricting the member actions by id" do
      expect(mapping.dig(:read, :params)).to eq(%i[id])
    end

    it "keeps writes in their own scope" do
      expect(mapping.dig(:create, :actions)).to eq(
        ["discourse_data_explorer/json_api_kit/queries#create"],
      )
    end

    it "lists the routes it covers, for the admin UI" do
      expect(mapping.dig(:read, :urls)).to include(
        "/data-explorer/api/queries (GET)",
        "/data-explorer/api/queries/:id (GET)",
      )
    end

    it "describes every action for the admin UI" do
      missing =
        mapping.keys.reject do |action|
          I18n.exists?("admin_js.admin.api.scopes.descriptions.queries.#{action}")
        end
      expect(missing).to eq([])
    end
  end

  # An endpoint that shouldn't take the defaults — an admin variant of a type, or a
  # coarser read/write split — says so on the controller.
  describe "overrides" do
    subject(:mapping) { DiscourseDataExplorer::JsonApiKit::ApiKeyScopes.mappings }

    let(:controller) { DiscourseDataExplorer::JsonApiKit::QueriesController }

    around do |example|
      controller.api_scopes(:admin_queries, read: %i[index], write: %i[create show])
      DiscourseDataExplorer::JsonApiKit::ApiKeyScopes.reset!
      example.run
    ensure
      controller.api_scopes(nil)
      DiscourseDataExplorer::JsonApiKit::ApiKeyScopes.reset!
    end

    it "renames the scope resource" do
      expect(mapping.keys).to eq([:admin_queries])
    end

    it "groups the actions as declared" do
      expect(mapping[:admin_queries][:read][:actions]).to eq(
        ["discourse_data_explorer/json_api_kit/queries#index"],
      )
    end

    it "puts the regrouped actions under their new name" do
      expect(mapping[:admin_queries][:write][:actions]).to contain_exactly(
        "discourse_data_explorer/json_api_kit/queries#create",
        "discourse_data_explorer/json_api_kit/queries#show",
      )
    end

    it "still allows restricting member actions by id" do
      expect(mapping[:admin_queries][:write][:params]).to eq(%i[id])
    end
  end

  context "with a key scoped to reading queries" do
    before { scope!("queries", "read") }

    it "serves the listing" do
      get "/data-explorer/api/queries", headers: headers
      expect(response.status).to eq(200)
    end

    it "serves a single query" do
      get "/data-explorer/api/queries/#{query.id}", headers: headers
      expect(response.status).to eq(200)
    end

    it "refuses to create" do
      post "/data-explorer/api/queries", params: create_body, as: :json, headers: headers
      expect(response.status).to eq(403)
    end
  end

  context "with a key scoped to creating queries" do
    before { scope!("queries", "create") }

    it "creates" do
      post "/data-explorer/api/queries", params: create_body, as: :json, headers: headers
      expect(response.status).to eq(201)
    end

    it "refuses to read" do
      get "/data-explorer/api/queries", headers: headers
      expect(response.status).to eq(403)
    end
  end

  context "with a key scoped to another resource" do
    before { scope!("topics", "read") }

    it "refuses the request" do
      get "/data-explorer/api/queries", headers: headers
      expect(response.status).to eq(403)
    end
  end

  context "with a key restricted to specific query ids" do
    fab!(:other_query) { Fabricate(:query, hidden: false) }

    before { scope!("queries", "read", allowed_parameters: { "id" => [query.id.to_s] }) }

    it "serves the allowed query" do
      get "/data-explorer/api/queries/#{query.id}", headers: headers
      expect(response.status).to eq(200)
    end

    it "refuses the other query" do
      get "/data-explorer/api/queries/#{other_query.id}", headers: headers
      expect(response.status).to eq(403)
    end

    # Same consequence as core's id-restricted scopes: a listing carries no id, so
    # it cannot be restricted to those ids and is refused.
    it "refuses the listing" do
      get "/data-explorer/api/queries", headers: headers
      expect(response.status).to eq(403)
    end
  end

  context "with an unscoped (global) key" do
    it "serves the listing" do
      get "/data-explorer/api/queries", headers: headers
      expect(response.status).to eq(200)
    end
  end
end
