# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowSettingField do
  fab!(:workflow, :discourse_workflows_workflow)

  it { is_expected.to belong_to(:workflow) }
  it { is_expected.to validate_presence_of(:label) }
  it { is_expected.to validate_length_of(:label).is_at_most(255) }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }
  it { is_expected.to validate_presence_of(:field_type) }
  it { is_expected.to validate_inclusion_of(:field_type).in_array(described_class::FIELD_TYPES) }

  it "validates key presence, length and format" do
    field = described_class.new(workflow:, label: "X", field_type: "string")

    expect(field).to validate_presence_of(:key)
    expect(field).to validate_length_of(:key).is_at_most(100)
    expect(field).to allow_values("valid_key", "Key_123", "_underscore").for(:key)
    expect(field).not_to allow_values("invalid key", "123start", "key!@#").for(:key)
  end

  it "validates key uniqueness scoped to the workflow" do
    Fabricate(:discourse_workflows_workflow_setting_field, workflow:, key: "priority")
    duplicate =
      described_class.new(workflow:, key: "priority", label: "Other", field_type: "string")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:key]).to be_present
  end

  it "allows the same key on a different workflow" do
    other_workflow = Fabricate(:discourse_workflows_workflow)
    Fabricate(:discourse_workflows_workflow_setting_field, workflow:, key: "priority")
    field =
      described_class.new(
        workflow: other_workflow,
        key: "priority",
        label: "Other",
        field_type: "string",
      )

    expect(field).to be_valid
  end

  describe "enum choices validation" do
    it "requires type_options.choices when field_type is enum" do
      field = described_class.new(workflow:, key: "priority", label: "Priority", field_type: "enum")

      expect(field).not_to be_valid
      expect(field.errors[:type_options]).to be_present
    end

    it "is valid when choices are present" do
      field =
        described_class.new(
          workflow:,
          key: "priority",
          label: "Priority",
          field_type: "enum",
          type_options: {
            "choices" => %w[low high],
          },
        )

      expect(field).to be_valid
    end
  end

  describe "#definition" do
    it "returns the field's portable definition without the value" do
      field =
        Fabricate(
          :discourse_workflows_workflow_setting_field,
          workflow:,
          key: "priority",
          label: "Priority",
          description: "How urgent",
          field_type: "enum",
          type_options: {
            "choices" => %w[low medium high],
          },
          value: "high",
        )

      expect(field.definition).to eq(
        "key" => "priority",
        "label" => "Priority",
        "description" => "How urgent",
        "type" => "enum",
        "type_options" => {
          "choices" => %w[low medium high],
        },
      )
    end
  end
end
