# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepOutcome do
  let(:step) { { "node_id" => "1", "status" => "running" } }

  describe ".success" do
    it "creates a success outcome with step and result" do
      result = [{ "json" => { "ok" => true } }]
      outcome = described_class.success(step: step, result: result)

      expect(outcome).to be_success
      expect(outcome).not_to be_wait
      expect(outcome).not_to be_error
      expect(outcome.step).to eq(step)
      expect(outcome.result).to eq(result)
      expect(outcome.wait).to be_nil
      expect(outcome.error).to be_nil
    end
  end

  describe ".wait" do
    it "creates a wait outcome with step and wait request" do
      wait = DiscourseWorkflows::WaitForWebhook.new
      outcome = described_class.wait(step: step, wait: wait)

      expect(outcome).to be_wait
      expect(outcome).not_to be_success
      expect(outcome).not_to be_error
      expect(outcome.step).to eq(step)
      expect(outcome.wait).to eq(wait)
      expect(outcome.result).to be_nil
      expect(outcome.error).to be_nil
    end
  end

  describe ".error" do
    it "creates an error outcome with step and error" do
      error = RuntimeError.new("boom")
      outcome = described_class.error(step: step, error: error)

      expect(outcome).to be_error
      expect(outcome).not_to be_success
      expect(outcome).not_to be_wait
      expect(outcome.step).to eq(step)
      expect(outcome.wait).to be_nil
      expect(outcome.error).to eq(error)
      expect(outcome.result).to be_nil
    end
  end
end
