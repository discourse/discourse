# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeExecution do
  it "calls the Execution::Resume service" do
    DiscourseWorkflows::Execution::Resume.expects(:call).with(
      params: {
        execution_id: 7,
        approved: true,
      },
    )

    described_class.new.execute(execution_id: 7, approved: true)
  end
end
