# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::Tools::DataTableSchema do
  fab!(:admin)
  fab!(:contacts) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "contacts",
      columns: [{ name: "email", type: "string" }, { name: "score", type: "number" }],
    ).tap { |data_table| insert_data_table_row(data_table, "email" => "a@example.com") }
  end
  fab!(:orders) { Fabricate(:discourse_workflows_data_table, name: "orders") }

  def invoke(agent_options: {}, **params)
    invoke_ai_tool(described_class, params, user: admin, agent_options:)
  end

  def names(result)
    result[:data_tables].map { |data_table| data_table[:name] }
  end

  it "is registered as an external tool alongside the query and write tools" do
    expect(DiscourseAi::Agents::Agent.external_tools).to include(
      described_class,
      DiscourseWorkflows::Ai::Tools::DataTableQuery,
      DiscourseWorkflows::Ai::Tools::DataTableWrite,
    )
  end

  it "lists tables with columns and row counts" do
    expect(invoke).to eq(
      status: "success",
      data_tables: [
        {
          id: contacts.id,
          name: "contacts",
          columns: [{ name: "email", type: "string" }, { name: "score", type: "number" }],
          row_count: 1,
        },
        {
          id: orders.id,
          name: "orders",
          columns: [{ name: "value", type: "string" }],
          row_count: 0,
        },
      ],
    )
  end

  it "narrows by query and by the allowed_tables option" do
    expect(names(invoke(query: "ord"))).to eq(%w[orders])
    expect(names(invoke(agent_options: { allowed_tables: "contacts" }))).to eq(%w[contacts])
    expect(names(invoke(agent_options: { allowed_tables: orders.id.to_s }))).to eq(%w[orders])
  end
end
