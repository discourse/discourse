# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Merge::V1 do
  def item(json)
    { "json" => json }
  end

  def execute_merge(input_1:, input_2:, input_groups: {}, configuration: {})
    execute_node_output(
      configuration: configuration,
      input_items: input_1,
      input_groups: { "input_1" => input_1, "input_2" => input_2 }.merge(input_groups),
    ).first
  end

  it "uses imported input wait semantics" do
    expect(described_class.input_ports).to contain_exactly(
      include(key: "main", required: false, multiple: true),
    )
    expect(described_class.required_inputs).to eq(1)
  end

  it "appends items from internal input groups" do
    output =
      execute_merge(
        input_1: [item("a" => 1)],
        input_2: [item("b" => 2)],
        input_groups: {
          "main" => [item("a" => 1), item("b" => 2)],
        },
      )

    expect(output).to eq([item("a" => 1), item("b" => 2)])
  end

  it "appends items from more than two internal input groups" do
    output =
      execute_merge(
        input_1: [item("a" => 1)],
        input_2: [item("b" => 2)],
        input_groups: {
          "input_3" => [item("c" => 3)],
        },
      )

    expect(output).to eq([item("a" => 1), item("b" => 2), item("c" => 3)])
  end
end
