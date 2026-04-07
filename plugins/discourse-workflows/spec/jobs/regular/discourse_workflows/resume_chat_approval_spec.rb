# frozen_string_literal: true

RSpec.describe Jobs::DiscourseWorkflows::ResumeChatApproval do
  it "calls the ChatApproval::Resume service" do
    DiscourseWorkflows::ChatApproval::Resume.expects(:call).with(
      params: {
        execution_id: 7,
        approved: true,
      },
    )

    described_class.new.execute(execution_id: 7, approved: true)
  end
end
