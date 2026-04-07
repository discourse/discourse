# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExecuteWorkflow do
  it "calls the Workflow::Execute service" do
    DiscourseWorkflows::Workflow::Execute
      .expects(:call)
      .with do |kwargs|
        expect(kwargs[:params]).to eq(
          { workflow_id: 99, trigger_node_id: "trigger-1", trigger_data: { "topic_id" => 1 } },
        )
      end

    described_class.new.execute(
      workflow_id: 99,
      trigger_node_id: "trigger-1",
      trigger_data: {
        "topic_id" => 1,
      },
    )
  end
end
