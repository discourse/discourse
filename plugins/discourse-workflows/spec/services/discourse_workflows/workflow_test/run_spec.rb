# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest::Run do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger-1", "trigger:manual", name: "Run manually"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end
    fab!(:first_test) { Fabricate(:discourse_workflows_workflow_test, workflow:) }
    fab!(:second_test) { Fabricate(:discourse_workflows_workflow_test, workflow:) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    context "when the feature is disabled" do
      before { SiteSetting.discourse_workflows_tests_enabled = false }

      it { is_expected.to fail_a_policy(:workflow_tests_enabled) }
    end

    context "when a requested test belongs to another workflow" do
      let(:params) do
        super().merge(test_ids: [first_test.id, Fabricate(:discourse_workflows_workflow_test).id])
      end

      it { is_expected.to fail_to_find_a_model(:workflow_tests) }
    end

    context "when the workflow has no tests" do
      before { workflow.workflow_tests.destroy_all }

      it { is_expected.to fail_to_find_a_model(:workflow_tests) }
    end

    context "when a test has no checks" do
      before { second_test.update_columns(checks: []) }

      it { is_expected.to fail_a_policy(:tests_have_checks) }
    end

    context "when running every test" do
      it "creates a pending simulation per test, points each test at it and enqueues the jobs" do
        expect { expect(result).to run_successfully }.to change {
          Jobs::DiscourseWorkflows::RunSimulation.jobs.size
        }.by(2)

        executions = result[:executions]
        expect(executions.map(&:workflow_test_id)).to contain_exactly(first_test.id, second_test.id)
        expect(executions).to all(have_attributes(status: "pending", execution_mode: "simulation"))
        expect(executions.first).to have_attributes(
          workflow_version_id: workflow.version_id,
          workflow_test_digest: first_test.definition_digest,
          pin_data_digest: workflow.pin_data_digest,
        )
        expect(first_test.reload.latest_execution_id).to eq(executions.first.id)
        expect(executions.first.execution_data.simulation).to eq("checks" => first_test.checks)
      end
    end

    context "when running one test" do
      let(:params) { super().merge(test_ids: [second_test.id]) }

      it "leaves the other test alone" do
        expect(result).to run_successfully
        expect(second_test.reload.latest_execution_id).to be_present
        expect(first_test.reload.latest_execution_id).to be_nil
      end
    end

    context "when the job cannot be enqueued" do
      before do
        Jobs
          .stubs(:enqueue)
          .with(Jobs::DiscourseWorkflows::RunSimulation, anything)
          .raises(Redis::CannotConnectError)
      end

      it "marks the execution as failed" do
        expect(result.failure?).to be(true)
        expect(first_test.reload.latest_execution).to have_attributes(
          status: "error",
          error: "Redis::CannotConnectError",
        )
      end
    end
  end
end
