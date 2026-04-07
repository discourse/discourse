# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ExpireWaitingExecutions do
  it "calls the Execution::ExpireWaiting service" do
    DiscourseWorkflows::Execution::ExpireWaiting.expects(:call)

    described_class.new.execute({})
  end
end
