# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::MarkdownTable::V1 do
  describe "#execute" do
    it "renders a table with a header row, separator, and one data row per input item" do
      items = [
        { "json" => { "name" => "Alice", "age" => "30" } },
        { "json" => { "name" => "Bob", "age" => "25" } },
      ]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [
            { "header" => "Name", "value" => "={{ $json.name }}" },
            { "header" => "Age", "value" => "={{ $json.age }}" },
          ],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown).to eq(<<~MD.strip)
        | Name | Age |
        | --- | --- |
        | Alice | 30 |
        | Bob | 25 |
      MD
    end

    it "JSON-encodes Hash cell values" do
      items = [{ "json" => { "h" => { "a" => 1, "b" => 2 } } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [{ "header" => "H", "value" => "={{ $json.h }}" }],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown.split("\n").last).to eq('| {"a":1,"b":2} |')
    end

    it "JSON-encodes Array cell values" do
      items = [{ "json" => { "arr" => [1, 2, 3] } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [{ "header" => "Arr", "value" => "={{ $json.arr }}" }],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown.split("\n").last).to eq("| [1,2,3] |")
    end

    it "renders nil cells as empty and stringifies scalars" do
      items = [{ "json" => { "maybe_nil" => nil, "int_val" => 42, "bool_val" => true } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [
            { "header" => "Nil", "value" => "={{ $json.maybe_nil }}" },
            { "header" => "Int", "value" => "={{ $json.int_val }}" },
            { "header" => "Bool", "value" => "={{ $json.bool_val }}" },
          ],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown.split("\n").last).to eq("|  | 42 | true |")
    end

    it "escapes pipe characters in cell values" do
      items = [{ "json" => { "text" => "a | b | c" } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [{ "header" => "Text", "value" => "={{ $json.text }}" }],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown.split("\n").last).to eq("| a \\| b \\| c |")
    end

    it "replaces newlines in cell values with <br>" do
      items = [{ "json" => { "text" => "line1\nline2\r\nline3" } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [{ "header" => "Text", "value" => "={{ $json.text }}" }],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown.split("\n").last).to eq("| line1<br>line2<br>line3 |")
    end

    it "keeps headers literal while resolving cell values through the execution context" do
      items = [{ "json" => { "header" => "Resolved header", "name" => "Alice" } }]
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [{ "header" => "={{ $json.header }}", "value" => "={{ $json.name }}" }],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown).to eq(<<~MD.strip)
        | ={{ $json.header }} |
        | --- |
        | Alice |
      MD
    end

    it "renders headers and separator only when input items are empty" do
      items = []
      config = {
        "mapping_mode" => "manual",
        "columns" => {
          "values" => [
            { "header" => "Name", "value" => "={{ $json.name }}" },
            { "header" => "Age", "value" => "={{ $json.age }}" },
          ],
        },
      }

      markdown =
        execute_node_output(configuration: config, input_items: items).first.first&.dig(
          "json",
          "markdown",
        )

      expect(markdown).to eq(<<~MD.strip)
        | Name | Age |
        | --- | --- |
      MD
    end

    it "returns an empty string when no columns are configured and no input items" do
      markdown =
        execute_node_output(
          configuration: {
            "mapping_mode" => "manual",
            "columns" => {
              "values" => [],
            },
          },
          input_items: [],
        ).first.first&.dig("json", "markdown")

      expect(markdown).to eq("")
    end

    context "when mapping_mode is auto" do
      it "derives headers from the keys of input items", :aggregate_failures do
        items = [
          { "json" => { "name" => "Alice", "age" => 30 } },
          { "json" => { "name" => "Bob", "age" => 25 } },
        ]

        output =
          execute_node_output(configuration: { "mapping_mode" => "auto" }, input_items: items)
            .first
            .first
            .fetch("json")

        expect(output.fetch("markdown")).to eq(<<~MD.strip)
          | name | age |
          | --- | --- |
          | Alice | 30 |
          | Bob | 25 |
        MD
        expect(output).to match_node_output_schema(described_class)
      end

      it "unions keys across items preserving first-appearance order" do
        items = [
          { "json" => { "name" => "Alice", "age" => 30 } },
          { "json" => { "name" => "Bob", "city" => "Paris" } },
        ]

        markdown =
          execute_node_output(configuration: { "mapping_mode" => "auto" }, input_items: items)
            .first
            .first
            &.dig("json", "markdown")

        expect(markdown).to eq(<<~MD.strip)
          | name | age | city |
          | --- | --- | --- |
          | Alice | 30 |  |
          | Bob |  | Paris |
        MD
      end

      it "JSON-encodes Hash and Array values" do
        items = [{ "json" => { "h" => { "a" => 1 }, "arr" => [1, 2] } }]

        markdown =
          execute_node_output(configuration: { "mapping_mode" => "auto" }, input_items: items)
            .first
            .first
            &.dig("json", "markdown")

        expect(markdown.split("\n").last).to eq('| {"a":1} | [1,2] |')
      end
    end
  end
end
