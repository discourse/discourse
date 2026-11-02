# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::OutputSchemasController do
  fab!(:admin)
  fab!(:user)
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "zzz",
      columns: [{ "name" => "email", "type" => "string" }],
    )
  end

  let(:nodes) do
    [
      {
        "id" => "form",
        "type" => "trigger:form",
        "typeVersion" => "1.0",
        "name" => "Form",
        "parameters" => {
          "form_fields" => {
            "values" => [{ "field_label" => "Größe", "field_type" => "text" }],
          },
        },
      },
      {
        "id" => "table",
        "type" => "action:data_table",
        "typeVersion" => "1.0",
        "name" => "Table",
        "parameters" => {
          "operation" => "get",
          "data_table_id" => data_table.id,
        },
      },
    ]
  end

  let(:connections) do
    { "Form" => { "main" => [[{ "node" => "Table", "type" => "main", "index" => 0 }]] } }
  end

  def resolve(payload)
    post "/admin/plugins/discourse-workflows/output-schemas.json", params: payload, as: :json
  end

  context "when logged in as an admin" do
    before { sign_in(admin) }

    it "returns each node's output schemas resolved on the server" do
      resolve(nodes:, connections:)

      expect(response.status).to eq(200)
      schemas = response.parsed_body["output_schemas"]
      expect(schemas.dig("form", 0, "properties").keys).to include("grosse")
      expect(schemas.dig("table", 0, "properties").keys).to include("id", "email")
    end

    it "rejects a payload without nodes" do
      resolve(nodes: [], connections:)

      expect(response.status).to eq(400)
    end

    it "fails when the graph does not converge" do
      allow(DiscourseWorkflows::Schema).to receive(:resolve_graph).and_raise(
        DiscourseWorkflows::Schema::GraphResolver::NotConverged,
      )

      resolve(nodes:, connections:)

      expect(response.status).to eq(422)
    end

    it "does not hide node schema errors behind a 422" do
      allow(DiscourseWorkflows::Nodes::DataTable::V1).to receive(:output_schemas).and_raise(
        ArgumentError,
      )

      resolve(nodes:, connections:)

      expect(response.status).to eq(500)
    end

    it "ignores connections with a malformed input index" do
      resolve(
        nodes:,
        connections: {
          "Form" => {
            "main" => [
              [
                { "node" => "Table", "type" => "main", "index" => {} },
                { "node" => "Table", "type" => "main", "index" => 10**9 },
              ],
            ],
          },
        },
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("output_schemas", "table", 0, "properties").keys).to include(
        "email",
      )
    end

    it "is rate limited" do
      RateLimiter.enable
      stub_const(described_class, "RATE_LIMIT", 1) do
        resolve(nodes:, connections:)
        expect(response.status).to eq(200)

        resolve(nodes:, connections:)
        expect(response.status).to eq(429)
      end
    ensure
      RateLimiter.disable
    end
  end

  it "is forbidden for non-admins" do
    sign_in(user)

    resolve(nodes:, connections:)

    expect(response.status).to eq(404)
  end
end
