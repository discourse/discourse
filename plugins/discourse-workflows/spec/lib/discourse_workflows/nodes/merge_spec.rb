# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Merge::V1 do
  def item(json)
    { "json" => json }
  end

  def json_items(items)
    items.map { |entry| { "json" => entry["json"] } }
  end

  def execute_merge(inputs:, input_groups: {}, configuration: {})
    indexed_groups = inputs.each_with_index.to_h { |items, index| ["input_#{index + 1}", items] }

    execute_node_output(
      configuration: configuration,
      input_items: inputs.first,
      input_groups: indexed_groups.merge(input_groups),
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
        inputs: [[item("a" => 1)], [item("b" => 2)]],
        input_groups: {
          "main" => [item("a" => 1), item("b" => 2)],
        },
      )

    expect(output).to eq([item("a" => 1), item("b" => 2)])
  end

  it "appends items from more than two internal input groups" do
    output = execute_merge(inputs: [[item("a" => 1)], [item("b" => 2)], [item("c" => 3)]])

    expect(output).to eq([item("a" => 1), item("b" => 2), item("c" => 3)])
  end

  it "combines items by position" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
          "resolve_clash" => "prefer_last",
        },
        inputs: [[item("id" => 1, "a" => "A")], [item("b" => "B")]],
      )

    expect(json_items(output)).to eq([item("id" => 1, "a" => "A", "b" => "B")])
  end

  it "pairs items by index and records pairedItem lineage" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
          "resolve_clash" => "prefer_last",
        },
        inputs: [[item("a" => 1), item("a" => 2)], [item("b" => 3), item("b" => 4)]],
      )

    expect(json_items(output)).to eq([item("a" => 1, "b" => 3), item("a" => 2, "b" => 4)])
    expect(output.first["pairedItem"]).to eq(
      [{ "input" => 0, "item" => 0 }, { "input" => 1, "item" => 0 }],
    )
  end

  it "defaults clash handling to add_suffix (matches n8n position combine)" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
        },
        inputs: [[item("markdown" => "table 1")], [item("markdown" => "table 2")]],
      )

    expect(json_items(output)).to eq([item("markdown_1" => "table 1", "markdown_2" => "table 2")])
  end

  it "combines multiple inputs by position" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
        },
        inputs: [
          [item("markdown" => "table 1")],
          [item("markdown" => "table 2")],
          [item("markdown" => "table 3")],
        ],
      )

    expect(json_items(output)).to eq(
      [item("markdown_1" => "table 1", "markdown_2" => "table 2", "markdown_3" => "table 3")],
    )
  end

  it "prefers input 1 on a clash when configured" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
          "resolve_clash" => "prefer_first",
        },
        inputs: [[item("value" => "one")], [item("value" => "two")]],
      )

    expect(json_items(output)).to eq([item("value" => "one")])
  end

  it "drops unpaired items by default when inputs differ in length" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
          "resolve_clash" => "prefer_last",
        },
        inputs: [[item("a" => 1), item("a" => 2)], [item("b" => 3)]],
      )

    expect(json_items(output)).to eq([item("a" => 1, "b" => 3)])
  end

  it "keeps unpaired items when include_unpaired is enabled" do
    output =
      execute_merge(
        configuration: {
          "mode" => "combine",
          "resolve_clash" => "prefer_last",
          "include_unpaired" => true,
        },
        inputs: [[item("a" => 1), item("a" => 2)], [item("b" => 3)]],
      )

    expect(json_items(output)).to eq([item("a" => 1, "b" => 3), item("a" => 2)])
  end
end
