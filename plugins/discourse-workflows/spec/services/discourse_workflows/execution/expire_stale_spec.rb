# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::ExpireStale do
  describe ".call" do
    subject(:result) { described_class.call }

    before do
      SiteSetting.discourse_workflows_run_timeout_minutes = 10
      freeze_time
    end

    context "when plugin is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when there are no stale executions" do
      it { is_expected.to run_successfully }
    end

    context "with executions of various ages and statuses" do
      let!(:stale_running) do
        Fabricate(:discourse_workflows_execution, status: :running, updated_at: 21.minutes.ago)
      end
      let!(:stale_pending) do
        Fabricate(:discourse_workflows_execution, status: :pending, updated_at: 21.minutes.ago)
      end
      let!(:stale_waiting) do
        Fabricate(:discourse_workflows_execution, status: :waiting, updated_at: 21.minutes.ago)
      end
      let!(:recent_running) do
        Fabricate(:discourse_workflows_execution, status: :running, updated_at: 19.minutes.ago)
      end

      it "fails only pending and running executions past the timeout and grace period" do
        result

        expect(
          [stale_running, stale_pending, stale_waiting, recent_running].map do |execution|
            execution.reload.status
          end,
        ).to eq(%w[error error waiting running])
      end
    end
  end
end
