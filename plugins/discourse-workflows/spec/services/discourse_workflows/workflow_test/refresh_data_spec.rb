# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest::RefreshData do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger-1", "trigger:manual", name: "Run manually"
          builder.node "topic-1",
                       "action:topic",
                       name: "Get topic",
                       configuration: {
                         "operation" => "get",
                         "topic_id" => 1,
                       }
          builder.node "http-1",
                       "action:http_request",
                       name: "Call API",
                       configuration: {
                         "url" => "https://example.com",
                       }
          builder.chain "trigger-1", "topic-1", "http-1"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end
    fab!(:workflow_test) do
      Fabricate(
        :discourse_workflows_workflow_test,
        workflow:,
        captured_at: 1.day.ago,
        captured_outputs: {
          "Get topic:0" => [{ "fingerprint" => "a", "outputs" => [] }],
          "Call API:0" => [{ "fingerprint" => "b", "outputs" => [] }],
        },
        pasted_responses: {
          "Call API" => [{ "json" => {} }],
        },
      )
    end

    let(:params) { { workflow_id: workflow.id, test_id: workflow_test.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    context "when the test has no checks" do
      before { workflow_test.update_columns(checks: []) }

      it { is_expected.to fail_a_policy(:test_has_checks) }
    end

    it "discards captured lookups, keeps recorded and pasted responses, and runs the test" do
      expect { expect(result).to run_successfully }.to change {
        Jobs::DiscourseWorkflows::RunSimulation.jobs.size
      }.by(1)

      workflow_test.reload
      expect(workflow_test.captured_outputs.keys).to eq(["Call API:0"])
      expect(workflow_test.pasted_responses.keys).to eq(["Call API"])
      expect(workflow_test.captured_at).to be_nil
      expect(workflow_test.latest_execution_id).to eq(result[:execution].id)
    end
  end
end
