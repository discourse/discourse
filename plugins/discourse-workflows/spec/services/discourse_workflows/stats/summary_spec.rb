# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Stats::Summary do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when there are no executions" do
      it { is_expected.to run_successfully }

      it "returns zeroed stats" do
        expect(result[:stats]).to eq(total: 0, failed: 0, failure_rate: "0%", avg_duration: "0ms")
      end
    end

    context "when there are recent executions" do
      before do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :success,
          started_at: 2.hours.ago,
          finished_at: 2.hours.ago + 10.seconds,
        )
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :success,
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 20.seconds,
        )
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :error,
          started_at: 30.minutes.ago,
          finished_at: 30.minutes.ago + 30.seconds,
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
          Fabricate(
            :discourse_workflows_execution,
            workflow: workflow,
            status: :success,
            started_at: 10.days.ago,
            finished_at: 10.days.ago + 5.seconds,
          )
        execution.update_column(:created_at, 10.days.ago)
      end

      it { is_expected.to run_successfully }

      it "does not count old executions" do
        expect(result[:stats]).to eq(total: 0, failed: 0, failure_rate: "0%", avg_duration: "0ms")
      end
    end

    context "when filtering by workflow_id" do
      fab!(:other_workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

      before do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :success,
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 10.seconds,
        )
        Fabricate(
          :discourse_workflows_execution,
          workflow: other_workflow,
          status: :success,
          started_at: 1.hour.ago,
          finished_at: 1.hour.ago + 20.seconds,
        )
      end

      let(:params) { { workflow_id: workflow.id } }

      it { is_expected.to run_successfully }

      it "only counts executions for the specified workflow" do
        expect(result[:stats][:total]).to eq(1)
      end
    end
  end
end
