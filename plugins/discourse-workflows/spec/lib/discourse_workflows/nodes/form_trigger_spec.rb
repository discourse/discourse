# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FormTrigger::V1 do
  describe "#output" do
    it "returns compatible form data and metadata" do
      trigger =
        described_class.new(
          form_data: {
            name: "Test",
          },
          submitted_at: "2026-01-01T00:00:00.000Z",
          query_parameters: {
            source: "email",
          },
        )

      expect(trigger.output).to eq(
        "name" => "Test",
        "submitted_at" => "2026-01-01T00:00:00.000Z",
        "form_mode" => "production",
        "form_query_parameters" => {
          "source" => "email",
        },
      )
    end
  end

  describe ".output_schemas" do
    let(:configuration) do
      {
        "form_fields" => {
          "values" => [
            { "field_label" => "Full name", "field_type" => "text" },
            { "field_label" => "Age", "field_type" => "number" },
            { "field_label" => "Agree", "field_type" => "checkbox" },
            { "field_label" => "Source", "field_name" => "src", "field_type" => "hiddenField" },
            { "field_label" => "Intro", "field_type" => "html", "html" => "<p>Hi</p>" },
            { "field_label" => "Dynamic", "field_type" => "={{ $json.type }}" },
          ],
        },
      }
    end

    it "derives properties from the configured form fields" do
      schema = described_class.output_schemas(configuration).first

      expect(schema["properties"].keys).to eq(
        %w[full_name age agree src dynamic submitted_at form_mode form_query_parameters],
      )
      expect(schema.dig("properties", "dynamic")).to eq({})
    end

    it "matches the output of a validated submission" do
      fields = DiscourseWorkflows::CollectionParameters.rows(configuration, "form_fields")
      result =
        DiscourseWorkflows::Schemas::FormFields.validate_submission(
          fields,
          { "full_name" => "Jane", "age" => "42", "agree" => "true", "dynamic" => "x" },
        )

      expect(described_class.new(form_data: result.data).output).to match_node_output_schema(
        described_class,
        configuration: configuration,
      )
    end
  end
end
