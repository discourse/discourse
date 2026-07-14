# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeIssues do
  def node_type_class(schema)
    Class.new { define_singleton_method(:property_schema) { schema } }
  end

  def node(configuration)
    DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
      id: "n1",
      type: "action:test",
      type_version: "1.0",
      name: "Test",
      parameters: configuration,
    )
  end

  it "returns no issues when all required fields are set" do
    schema = { form_title: { type: :string, required: true } }
    issues = described_class.for_node(node("form_title" => "My form"), node_type_class(schema))
    expect(issues).to be_empty
  end

  it "reports a top-level required field as missing" do
    schema = { form_title: { type: :string, required: true } }
    issues = described_class.for_node(node({}), node_type_class(schema))
    expect(issues).to eq([{ path: "form_title", name: "form_title", message: "required" }])
  end

  it "treats blank strings as missing" do
    schema = { form_title: { type: :string, required: true } }
    issues = described_class.for_node(node("form_title" => "   "), node_type_class(schema))
    expect(issues.size).to eq(1)
  end

  it "walks fixed collection items and reports missing nested required fields" do
    schema = {
      form_fields: {
        type: :fixed_collection,
        options: [
          {
            name: "values",
            values: {
              field_label: {
                type: :string,
                required: true,
              },
              field_type: {
                type: :options,
                required: true,
              },
            },
          },
        ],
      },
    }
    config = {
      "form_fields" => {
        "values" => [
          { "field_label" => "", "field_type" => "text" },
          { "field_label" => "Name", "field_type" => "" },
        ],
      },
    }

    paths = described_class.for_node(node(config), node_type_class(schema)).map { |i| i[:path] }
    expect(paths).to contain_exactly(
      "form_fields.values.0.field_label",
      "form_fields.values.1.field_type",
    )
  end

  it "respects display_options show rules — hidden required fields are not reported" do
    schema = {
      page_type: {
        type: :options,
      },
      completion_title: {
        type: :string,
        required: true,
        display_options: {
          show: {
            page_type: %w[completion],
          },
        },
      },
    }

    expect(
      described_class.for_node(node("page_type" => "page"), node_type_class(schema)),
    ).to be_empty

    issues = described_class.for_node(node("page_type" => "completion"), node_type_class(schema))
    expect(issues.size).to eq(1)
  end

  it "applies field defaults before checking required" do
    schema = { operation: { type: :options, required: true, default: "add" } }
    expect(described_class.for_node(node({}), node_type_class(schema))).to be_empty
  end

  it "walks optional fields inside fixed collections" do
    schema = {
      form_fields: {
        type: :fixed_collection,
        options: [
          {
            name: "values",
            values: {
              field_label: {
                type: :string,
                required: true,
              },
              custom_required: {
                type: :string,
                required: true,
              },
            },
          },
        ],
      },
    }
    config = { "form_fields" => { "values" => [{ "field_label" => "Name" }] } }
    paths = described_class.for_node(node(config), node_type_class(schema)).map { |i| i[:path] }
    expect(paths).to eq(["form_fields.values.0.custom_required"])
  end
end
