# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::DataTableQuery do
  fab!(:admin)
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "Contacts",
      columns: [{ name: "email", type: "string" }, { name: "score", type: "number" }],
    ).tap do |data_table|
      [["a@example.com", 1], ["b@example.com", 5], ["c@example.com", 10]].each do |email, score|
        insert_data_table_row(data_table, "email" => email, "score" => score)
      end
    end
  end

  def invoke(agent_options: {}, **params)
    invoke_ai_tool(described_class, params, user: admin, agent_options:)
  end

  it "filters, sorts and pages rows" do
    result =
      invoke(
        table: "Contacts",
        filter: {
          filters: [{ columnName: "score", condition: "gte", value: "5" }],
        },
        sort_by: "score",
        sort_direction: "desc",
        limit: 1,
        offset: 1,
      )

    expect(result).to include(status: "success", table: "Contacts", count: 2)
    expect(result[:rows].map { |row| row["email"] }).to eq(%w[b@example.com])
  end

  it "resolves the table by id or case-insensitive name and clamps a zero limit to one row" do
    result = invoke(table: data_table.id.to_s, limit: 0)

    expect(result).to include(status: "success", count: 3)
    expect(result[:rows].size).to eq(1)
    expect(invoke(table: "contacts", agent_options: { allowed_tables: "CONTACTS" })).to include(
      status: "success",
      count: 3,
    )
  end

  it "returns errors for unknown tables, tables outside allowed_tables and bad offsets" do
    expect(invoke(table: "people")).to eq(status: "error", error: "Unknown data table 'people'")
    expect(invoke(table: "Contacts", offset: true)).to eq(
      status: "error",
      error: "offset must be an integer",
    )
    expect(invoke(table: "Contacts", agent_options: { allowed_tables: "other" })).to eq(
      status: "error",
      error: "Unknown data table 'Contacts'",
    )
  end

  it "lets programming errors propagate instead of reporting them to the model" do
    tool = build_ai_tool(described_class, { table: "Contacts" }, user: admin)
    tool.stubs(:node_proxy).raises(ArgumentError, "unknown keyword: :foo")

    expect { tool.invoke }.to raise_error(ArgumentError, "unknown keyword: :foo")
  end
end
