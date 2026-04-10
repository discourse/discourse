# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Error::V1 do
  describe ".output_schema" do
    it "describes the error data fields" do
      schema = described_class.output_schema
      expect(schema).to eq(error_message: :string, failed_node_name: :string)
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
