# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Stats::Summary do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)
    fab!(:workflow, :discourse_workflows_workflow) do
      Fabricate(:discourse_workflows_workflow, created_by: user)
    end

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when there are no executions" do
      it { is_expected.to run_successfully }

      it "returns zeroed stats" do
        expect(result[:stats]).to eq(total: 0, failed: 0, failure_rate: "0%", avg_duration: "0ms")
      end
    end

    context "when there are recent executions" do
      before do
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :success,
          started_at: 2.hours.ago,
          finished_at: 2.hours.ago + 10.seconds,
          trigger_data: {
          },
        )
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :success,
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 20.seconds,
          trigger_data: {
          },
        )
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          status: :error,
          started_at: 30.minutes.ago,
          finished_at: 30.minutes.ago + 30.seconds,
          trigger_data: {
          },
        )
      end

      it { is_expected.to run_successfully }

      it "computes correct stats" do
        stats = result[:stats]
        expect(stats[:total]).to eq(3)
        expect(stats[:failed]).to eq(1)
        expect(stats[:failure_rate]).to eq("33.3%")
        expect(stats[:avg_duration]).to eq("20.0s")
      end
    end

    context "when executions are older than 7 days" do
      before do
        execution =
          DiscourseWorkflows::Execution.create!(
            workflow: workflow,
            status: :success,
            started_at: 10.days.ago,
            finished_at: 10.days.ago + 5.seconds,
            trigger_data: {
            },
          )
        execution.update_column(:created_at, 10.days.ago)
      end

      it { is_expected.to run_successfully }

      it "does not count old executions" do
        expect(result[:stats]).to eq(total: 0, failed: 0, failure_rate: "0%", avg_duration: "0ms")
      end
    end
  end
end
