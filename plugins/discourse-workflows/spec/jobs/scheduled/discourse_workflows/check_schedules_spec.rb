# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::CheckSchedules do
  it "calls the Execution::CheckSchedules service" do
    DiscourseWorkflows::Execution::CheckSchedules.expects(:call)

    described_class.new.execute({})
  end
end
