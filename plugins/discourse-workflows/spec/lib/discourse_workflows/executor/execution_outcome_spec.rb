# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionOutcome do
  describe ".complete" do
    it "creates a complete outcome" do
      outcome = described_class.complete

      expect(outcome).to be_complete
      expect(outcome).not_to be_wait
      expect(outcome.wait).to be_nil
    end
  end

  describe ".wait" do
    it "creates a wait outcome" do
      wait = DiscourseWorkflows::WaitForWebhook.new
      outcome = described_class.wait(wait: wait)

      expect(outcome).to be_wait
      expect(outcome).not_to be_complete
      expect(outcome.wait).to eq(wait)
    end
  end
end
