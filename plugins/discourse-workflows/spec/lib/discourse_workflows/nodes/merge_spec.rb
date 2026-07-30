# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Merge::V1 do
  it "uses imported input wait semantics" do
    expect(described_class.input_ports).to contain_exactly(
      include(key: "main", required: false, multiple: true),
    )
    expect(described_class.required_inputs).to eq(1)
  end

  it "appends items from internal input groups" do
    inputs = [[{ "json" => { "a" => 1 } }], [{ "json" => { "b" => 2 } }]]
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: {
        },
        input_items: inputs.first,
        input_groups:
          indexed_groups.merge(
            { "main" => [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }] },
          ),
      ).first

    expect(output).to eq([{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }])
  end

  it "appends items from more than two internal input groups" do
    inputs = [
      [{ "json" => { "a" => 1 } }],
      [{ "json" => { "b" => 2 } }],
      [{ "json" => { "c" => 3 } }],
    ]
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: {
        },
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output).to eq(
      [{ "json" => { "a" => 1 } }, { "json" => { "b" => 2 } }, { "json" => { "c" => 3 } }],
    )
  end

  it "combines items by position" do
    inputs = [[{ "json" => { "id" => 1, "a" => "A" } }], [{ "json" => { "b" => "B" } }]]
    configuration = { "mode" => "combine", "resolve_clash" => "prefer_last" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "id" => 1, "a" => "A", "b" => "B" } }],
    )
  end

  it "pairs items by index and records pairedItem lineage" do
    inputs = [
      [{ "json" => { "a" => 1 } }, { "json" => { "a" => 2 } }],
      [{ "json" => { "b" => 3 } }, { "json" => { "b" => 4 } }],
    ]
    configuration = { "mode" => "combine", "resolve_clash" => "prefer_last" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "a" => 1, "b" => 3 } }, { "json" => { "a" => 2, "b" => 4 } }],
    )
    expect(output.first["pairedItem"]).to eq(
      [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 0 }],
    )
  end

  it "defaults clash handling to add_suffix (matches n8n position combine)" do
    inputs = [
      [{ "json" => { "markdown" => "table 1" } }],
      [{ "json" => { "markdown" => "table 2" } }],
    ]
    configuration = { "mode" => "combine" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "markdown_1" => "table 1", "markdown_2" => "table 2" } }],
    )
  end

  it "combines multiple inputs by position" do
    inputs = [
      [{ "json" => { "markdown" => "table 1" } }],
      [{ "json" => { "markdown" => "table 2" } }],
      [{ "json" => { "markdown" => "table 3" } }],
    ]
    configuration = { "mode" => "combine" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [
        {
          "json" => {
            "markdown_1" => "table 1",
            "markdown_2" => "table 2",
            "markdown_3" => "table 3",
          },
        },
      ],
    )
  end

  it "prefers input 1 on a clash when configured" do
    inputs = [[{ "json" => { "value" => "one" } }], [{ "json" => { "value" => "two" } }]]
    configuration = { "mode" => "combine", "resolve_clash" => "prefer_first" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "value" => "one" } }],
    )
  end

  it "drops unpaired items by default when inputs differ in length" do
    inputs = [
      [{ "json" => { "a" => 1 } }, { "json" => { "a" => 2 } }],
      [{ "json" => { "b" => 3 } }],
    ]
    configuration = { "mode" => "combine", "resolve_clash" => "prefer_last" }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "a" => 1, "b" => 3 } }],
    )
  end

  it "keeps unpaired items when include_unpaired is enabled" do
    inputs = [
      [{ "json" => { "a" => 1 } }, { "json" => { "a" => 2 } }],
      [{ "json" => { "b" => 3 } }],
    ]
    configuration = {
      "mode" => "combine",
      "resolve_clash" => "prefer_last",
      "include_unpaired" => true,
    }
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }
    output =
      execute_node_output(
        configuration: configuration,
        input_items: inputs.first,
        input_groups: indexed_groups,
      ).first

    expect(output.map { |entry| { "json" => entry["json"] } }).to eq(
      [{ "json" => { "a" => 1, "b" => 3 } }, { "json" => { "a" => 2 } }],
    )
  end
end
