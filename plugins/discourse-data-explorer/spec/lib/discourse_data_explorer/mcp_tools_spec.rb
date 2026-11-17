# frozen_string_literal: true

describe DiscourseDataExplorer::McpTools::GetQuery do
  fab!(:admin)
  fab!(:moderator)
  fab!(:group)
  fab!(:query) do
    Fabricate(
      :query,
      user: admin,
      name: "Active members",
      description: "Lists active members",
      sql: "-- [params]\n-- int :minimum_id = 1\nSELECT :minimum_id::integer AS value",
    )
  end

  def request_context(user)
    instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
  end

  before { SiteSetting.data_explorer_enabled = true }

  it "returns saved query details to an admin" do
    result =
      described_class.call(
        arguments: {
          "id" => query.id,
        },
        request_context: request_context(admin),
      ).fetch(:structuredContent)

    expect(result).to eq(
      id: query.id,
      name: "Active members",
      description: "Lists active members",
      username: admin.username,
      group_ids: [],
      last_run_at: nil,
      sql: query.sql,
      param_info: [{ identifier: "minimum_id", type: "int", default: "1", nullable: false }],
    )
    expect(
      JSONSchemer.schema(DiscourseDataExplorer::McpTools::GetQuery::OUTPUT_SCHEMA).valid?(
        JSON.parse(JSON.generate(result)),
      ),
    ).to eq(true)
  end

  it "does not expose SQL to a moderator who can run the query" do
    group.add(moderator)
    Fabricate(:query_group, query:, group:)

    expect do
      described_class.call(
        arguments: {
          "id" => query.id,
        },
        request_context: request_context(moderator),
      )
    end.to raise_error(Discourse::InvalidAccess)
  end

  it "does not expose hidden queries" do
    query.update!(hidden: true)

    expect do
      described_class.call(arguments: { "id" => query.id }, request_context: request_context(admin))
    end.to raise_error(
      DiscourseMcp::ToolError,
      I18n.t("discourse_data_explorer.mcp.query_not_found"),
    )
  end
end

describe DiscourseDataExplorer::McpTools::RunQuery do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:group)
  fab!(:query) do
    Fabricate(
      :query,
      user: admin,
      sql: "-- [params]\n-- int :value = 1\nSELECT :value::integer AS value",
    )
  end

  def request_context(user)
    instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
  end

  before do
    SiteSetting.data_explorer_enabled = true
    group.add(user)
    Fabricate(:query_group, query:, group:)
  end

  after { DiscourseDataExplorer::QueryRunner.invalidate(query.id) }

  it "runs an assigned query with parameters for a group member" do
    result =
      described_class.call(
        arguments: {
          "id" => query.id,
          "params" => {
            "value" => 42,
          },
          "limit" => 1,
        },
        request_context: request_context(user),
      ).fetch(:structuredContent)

    expect(result).to include(columns: ["value"], rows: [[42]], result_count: 1)
    expect(result[:duration_ms]).to be_a(Numeric)
    expect(result.keys).to contain_exactly(:columns, :rows, :result_count, :duration_ms)
    schema_errors =
      JSONSchemer
        .schema(DiscourseDataExplorer::McpTools::RunQuery::OUTPUT_SCHEMA)
        .validate(JSON.parse(JSON.generate(result)))
        .to_a
    expect(schema_errors).to be_empty
    expect(query.reload.last_run_at).to be_present
  end

  it "lets an admin run a query without a group assignment" do
    query.query_groups.delete_all

    result =
      described_class.call(
        arguments: {
          "id" => query.id,
        },
        request_context: request_context(admin),
      ).fetch(:structuredContent)

    expect(result).to include(columns: ["value"], rows: [[1]])
  end

  it "does not expose a query to a moderator without access" do
    expect do
      described_class.call(
        arguments: {
          "id" => query.id,
        },
        request_context: request_context(moderator),
      )
    end.to raise_error(
      DiscourseMcp::ToolError,
      I18n.t("discourse_data_explorer.mcp.query_not_found"),
    )
  end

  it "does not run a hidden query" do
    query.update!(hidden: true)

    expect do
      described_class.call(arguments: { "id" => query.id }, request_context: request_context(user))
    end.to raise_error(
      DiscourseMcp::ToolError,
      I18n.t("discourse_data_explorer.mcp.query_not_found"),
    )
  end

  it "reports query execution errors" do
    query.update!(sql: "SELECT * FROM a_table_that_does_not_exist")

    expect do
      described_class.call(arguments: { "id" => query.id }, request_context: request_context(user))
    end.to raise_error(DiscourseMcp::ToolError, /a_table_that_does_not_exist/)
  end
end

describe DiscourseDataExplorer::McpTools do
  before { SiteSetting.data_explorer_enabled = true }

  it "registers both tools with the dedicated read scope" do
    tools =
      %w[discourse_get_query discourse_run_query].index_with do |identifier|
        DiscourseMcp.registry.find(:tool, identifier)
      end

    expect(tools.transform_values(&:required_scopes)).to eq(
      "discourse_get_query" => [DiscourseDataExplorer::McpTools::READ_SCOPE],
      "discourse_run_query" => [DiscourseDataExplorer::McpTools::READ_SCOPE],
    )
    expect(tools.transform_values(&:output_schema).values).to all(be_present)
    expect(tools["discourse_get_query"].input_schema.dig("properties", "id", "minimum")).to eq(1)
    expect(tools["discourse_run_query"].input_schema.dig("properties", "id")).to eq(
      "type" => "integer",
    )
    expect(
      JSONSchemer.schema(tools["discourse_run_query"].input_schema).valid?(
        { "id" => -1, "limit" => "ALL" },
      ),
    ).to eq(true)
  end

  it "hides both tools when Data Explorer is disabled" do
    SiteSetting.data_explorer_enabled = false

    expect(
      %w[discourse_get_query discourse_run_query].map do |identifier|
        DiscourseMcp.registry.find(:tool, identifier).available?
      end,
    ).to all(eq(false))
  end
end
