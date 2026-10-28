# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::DataTable::V1 do
  fab!(:data_table, :discourse_workflows_data_table)

  it "runs a read for real" do
    configuration = { "operation" => "get", "data_table_id" => data_table.id }

    output = simulate_node_output(configuration:)

    expect(output).to eq([[]])
  end

  it "blocks a write" do
    configuration = { "operation" => "insert", "data_table_id" => data_table.id, "columns" => {} }

    expect { simulate_node_output(configuration:) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("unsupported_operation") }
  end
end
