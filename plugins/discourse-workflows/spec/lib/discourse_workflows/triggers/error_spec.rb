# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::Error::V1 do
  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:error")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".output_schema" do
    it "describes the error data fields" do
      schema = described_class.output_schema
      expect(schema).to include(
        execution_id: :integer,
        workflow_id: :integer,
        workflow_name: :string,
        error_message: :string,
        failed_node_name: :string,
      )
    end
  end

  describe "#output" do
    it "returns the error data passed at initialization" do
      error_data = {
        execution_id: 42,
        workflow_id: 1,
        workflow_name: "My Workflow",
        error_message: "Something went wrong",
        failed_node_name: "HTTP Request",
      }
      trigger = described_class.new(error_data)
      expect(trigger.output).to eq(error_data)
    end
  end
end
