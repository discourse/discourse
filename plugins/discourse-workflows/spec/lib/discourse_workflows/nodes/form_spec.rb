# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Form::V1 do
  subject(:result) { described_class.new(parameters: configuration).execute(execution_context) }

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  let(:execution_context) do
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      parameters: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      resume_token: "tok-xyz",
    )
  end

  after { sandbox.dispose }

  describe "#execute" do
    context "with a non-completion form" do
      let(:configuration) do
        {
          "form_title" => "Approval",
          "form_description" => "Please approve",
          "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
        }
      end

      it "returns input items" do
        expect(result).to eq([execution_context.input_items])
      end
    end

    context "with a completion form" do
      let(:configuration) do
        {
          "page_type" => "completion",
          "on_submission" => "completion_screen",
          "completion_title" => "Done",
        }
      end

      it "passes through without reaching into flow context" do
        expect(result).to eq([execution_context.input_items])
      end
    end
  end

  describe ".output_schemas" do
    let(:configuration) do
      {
        "form_fields" => {
          "values" => [
            { "field_label" => "Reason", "field_type" => "text" },
            { "field_label" => "Approved", "field_type" => "checkbox" },
            { "field_label" => "Intro", "field_type" => "html", "html" => "<p>Hi</p>" },
          ],
        },
      }
    end

    it "derives the schema from the configured form fields like the form trigger" do
      expect(described_class.output_schemas(configuration)).to eq(
        DiscourseWorkflows::Nodes::FormTrigger::V1.output_schemas(configuration),
      )
    end

    it "passes the input schema through for a completion page" do
      input_schema = DiscourseWorkflows::Schema.document("source" => { "type" => "string" })

      expect(
        described_class.output_schemas(
          configuration.merge("page_type" => "completion"),
          input_schemas: [input_schema],
        ),
      ).to eq([input_schema])
    end
  end
end
