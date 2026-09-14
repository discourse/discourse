# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Variable do
  fab!(:workflow, :discourse_workflows_workflow)

  it { is_expected.to belong_to(:created_by) }
  it { is_expected.to belong_to(:workflow).optional }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }
  it { is_expected.to validate_presence_of(:variable_type) }

  it do
    is_expected.to validate_inclusion_of(:variable_type).in_array(described_class::VARIABLE_TYPES)
  end

  it "validates key presence, length and format" do
    variable = described_class.new(variable_type: "string")

    expect(variable).to validate_presence_of(:key)
    expect(variable).to validate_length_of(:key).is_at_most(100)
    expect(variable).to allow_values("valid_key", "Key_123", "_underscore").for(:key)
    expect(variable).not_to allow_values("invalid key", "123start", "key!@#").for(:key)
  end

  describe "key uniqueness" do
    it "is scoped to the workflow for workflow-scoped variables" do
      Fabricate(:discourse_workflows_workflow_variable, workflow:, key: "priority")
      duplicate = described_class.new(workflow:, key: "priority", variable_type: "string")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to be_present
    end

    it "allows the same key on a different workflow" do
      other_workflow = Fabricate(:discourse_workflows_workflow)
      Fabricate(:discourse_workflows_workflow_variable, workflow:, key: "priority")
      variable =
        described_class.new(workflow: other_workflow, key: "priority", variable_type: "string")

      expect(variable).to be_valid
    end

    it "is enforced across global variables" do
      Fabricate(:discourse_workflows_variable, key: "priority")
      duplicate = described_class.new(key: "priority", variable_type: "string")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to be_present
    end

    it "allows a local variable to share a key with a global variable" do
      Fabricate(:discourse_workflows_variable, key: "priority")
      variable = described_class.new(workflow:, key: "priority", variable_type: "string")

      expect(variable).to be_valid
    end

    it "allows a global variable to share a key with a local variable" do
      Fabricate(:discourse_workflows_workflow_variable, workflow:, key: "priority")
      variable = described_class.new(key: "priority", variable_type: "string")

      expect(variable).to be_valid
    end
  end

  describe "database-level uniqueness (partial indexes)" do
    it "allows two variables sharing a key when one is global and one is workflow-scoped" do
      Fabricate(:discourse_workflows_variable, key: "priority")

      expect {
        described_class.insert!(
          {
            key: "priority",
            workflow_id: workflow.id,
            variable_type: "string",
            created_by_id: workflow.created_by_id,
          },
        )
      }.not_to raise_error
    end

    it "allows two workflow-scoped variables sharing a key on different workflows" do
      other_workflow = Fabricate(:discourse_workflows_workflow)
      Fabricate(:discourse_workflows_workflow_variable, workflow:, key: "priority")

      expect {
        described_class.insert!(
          {
            key: "priority",
            workflow_id: other_workflow.id,
            variable_type: "string",
            created_by_id: other_workflow.created_by_id,
          },
        )
      }.not_to raise_error
    end

    it "rejects two workflow-scoped variables sharing a key on the same workflow" do
      Fabricate(:discourse_workflows_workflow_variable, workflow:, key: "priority")

      expect {
        described_class.insert!(
          {
            key: "priority",
            workflow_id: workflow.id,
            variable_type: "string",
            created_by_id: workflow.created_by_id,
          },
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects two global variables sharing a key" do
      global_variable = Fabricate(:discourse_workflows_variable, key: "priority")

      expect {
        described_class.insert!(
          {
            key: "priority",
            variable_type: "string",
            created_by_id: global_variable.created_by_id,
          },
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#label" do
    it "is derived from the key" do
      variable = described_class.new(key: "notify_categories")
      expect(variable.label).to eq("Notify categories")
    end

    it "handles a single-word key" do
      variable = described_class.new(key: "priority")
      expect(variable.label).to eq("Priority")
    end
  end

  describe "enum choices validation" do
    it "requires type_options.choices when variable_type is enum" do
      variable = described_class.new(workflow:, key: "priority", variable_type: "enum")

      expect(variable).not_to be_valid
      expect(variable.errors[:type_options]).to be_present
    end

    it "is valid when choices are present" do
      variable =
        described_class.new(
          workflow:,
          key: "priority",
          variable_type: "enum",
          type_options: {
            "choices" => %w[low high],
          },
        )

      expect(variable).to be_valid
    end
  end

  describe "#definition" do
    it "returns the variable's portable definition without the value" do
      variable =
        Fabricate(
          :discourse_workflows_workflow_variable,
          workflow:,
          key: "priority",
          description: "How urgent",
          variable_type: "enum",
          type_options: {
            "choices" => %w[low medium high],
          },
          value: "high",
        )

      expect(variable.definition).to eq(
        "key" => "priority",
        "description" => "How urgent",
        "type" => "enum",
        "type_options" => {
          "choices" => %w[low medium high],
        },
      )
    end
  end
end
