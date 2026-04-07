# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::CheckStaleTopics do
  it "calls the Execution::CheckStaleTopics service" do
    DiscourseWorkflows::Execution::CheckStaleTopics.expects(:call)

    described_class.new.execute(nil)
  end
end
