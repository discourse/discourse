# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeIssues do
  subject(:issues) { described_class.for_node(node, node_type) }

  let(:configuration) { {} }
  let(:options) { {} }
  let(:node) do
    DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
      id: "n1",
      type: "action:test",
      type_version: "1.0",
      name: "Test",
      parameters: configuration,
    )
  end
  let(:node_type) do
    Class
      .new do
        attr_reader :identifier, :version, :credentials

        def initialize(schema, options)
          @identifier = "action:test"
          @version = "1.0"
          @schema = schema
          @options = options
        end

        def property_schema
          @schema
        end

        def load_options_context(context)
          @options[context.method_name]
        end
      end
      .new(schema, options)
  end

  context "when all required fields are set" do
    let(:schema) { { form_title: { type: :string, required: true } } }
    let(:configuration) { { "form_title" => "My form" } }

    it { is_expected.to be_empty }
  end

  context "when a top-level required field is missing" do
    let(:schema) { { form_title: { type: :string, required: true } } }

    it "reports the field" do
      expect(issues).to eq([{ path: "form_title", name: "form_title", message: "required" }])
    end
  end

  context "when a required string is blank" do
    let(:schema) { { form_title: { type: :string, required: true } } }
    let(:configuration) { { "form_title" => "   " } }

    it "reports the field" do
      expect(issues.size).to eq(1)
    end
  end

  context "with missing required fields in fixed collection items" do
    let(:schema) do
      {
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
    end
    let(:configuration) do
      {
        "form_fields" => {
          "values" => [
            { "field_label" => "", "field_type" => "text" },
            { "field_label" => "Name", "field_type" => "" },
          ],
        },
      }
    end

    it "reports each nested path" do
      expect(issues.pluck(:path)).to contain_exactly(
        "form_fields.values.0.field_label",
        "form_fields.values.1.field_type",
      )
    end
  end

  context "with display rules on a required field" do
    let(:schema) do
      {
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
    end

    context "when the field is hidden" do
      let(:configuration) { { "page_type" => "page" } }

      it { is_expected.to be_empty }
    end

    context "when the field is shown" do
      let(:configuration) { { "page_type" => "completion" } }

      it "reports the field" do
        expect(issues.size).to eq(1)
      end
    end

    context "when the controlling parameter is an expression" do
      let(:configuration) { { "page_type" => "={{ $json.kind }}" } }

      it "does not report the blank required field" do
        expect(issues).to be_empty
      end
    end
  end

  context "with a collection behind an expression-valued anchor" do
    let(:schema) do
      {
        mode: {
          type: :options,
        },
        columns: {
          type: :fixed_collection,
          display_options: {
            show: {
              mode: %w[manual],
            },
          },
          options: [{ name: "values", values: { header: { type: :string, required: true } } }],
        },
      }
    end
    let(:configuration) do
      { "mode" => "={{ $json.mode }}", "columns" => { "values" => [{ "header" => "" }] } }
    end

    it "suppresses issues for the whole subtree" do
      expect(issues).to be_empty
    end

    context "when the anchor is a literal" do
      let(:configuration) do
        { "mode" => "manual", "columns" => { "values" => [{ "header" => "" }] } }
      end

      it "still reports the nested blank required field" do
        expect(issues.map { |issue| issue[:path] }).to eq(["columns.values.0.header"])
      end
    end
  end

  context "with an option metadata rule on a required field" do
    let(:schema) do
      {
        option_id: {
          type: :integer,
          type_options: {
            load_options_method: "options",
          },
        },
        detail: {
          type: :string,
          required: true,
          display_options: {
            hide: {
              option_id: [
                { condition: { metadata_flag: { collection: "options", flag: "hide_detail" } } },
              ],
            },
          },
        },
      }
    end
    let(:options) { { "options" => [{ id: 1, hide_detail: true }, { id: 2, hide_detail: false }] } }

    context "when the selected option hides the field" do
      let(:configuration) { { "option_id" => "1" } }

      it { is_expected.to be_empty }
    end

    context "when the selected option shows the field" do
      let(:configuration) { { "option_id" => "2" } }

      it "reports the missing required field" do
        expect(issues.pluck(:path)).to eq(["detail"])
      end
    end
  end

  context "when a required field has a default" do
    let(:schema) { { operation: { type: :options, required: true, default: "add" } } }

    it { is_expected.to be_empty }
  end

  context "with a missing optional field inside a fixed collection" do
    let(:schema) do
      {
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
    end
    let(:configuration) { { "form_fields" => { "values" => [{ "field_label" => "Name" }] } } }

    it "reports the nested field" do
      expect(issues.pluck(:path)).to eq(["form_fields.values.0.custom_required"])
    end
  end
end
