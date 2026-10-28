# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:execution_id) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger-1", "trigger:manual", name: "Run manually"
          builder.node "http-1",
                       "action:http_request",
                       name: "Call API",
                       configuration: {
                         "url" => "https://example.com",
                       }
          builder.chain "trigger-1", "http-1"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end

    let(:execution) { source_execution }
    let(:params) { { workflow_id: workflow.id, execution_id: execution.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    def source_execution(
      trigger_data: { "hello" => "world" },
      execution_mode: :manual,
      status: :success,
      data: nil
    )
      execution =
        Fabricate(
          :discourse_workflows_completed_execution,
          workflow:,
          trigger_node_id: "trigger-1",
          trigger_data:,
          execution_mode:,
          status:,
        )
      Fabricate(
        :discourse_workflows_execution_data,
        execution:,
        workflow_data:
          DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false).to_h,
        data: data || { "entries" => {}, "context" => {}, "node_contexts" => {}, "run_data" => {} },
      )
      execution
    end

    context "when the feature is disabled" do
      before { SiteSetting.discourse_workflows_tests_enabled = false }

      it { is_expected.to fail_a_policy(:workflow_tests_enabled) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the execution belongs to another workflow" do
      let(:execution) { Fabricate(:discourse_workflows_completed_execution) }

      it { is_expected.to fail_to_find_a_model(:source_execution) }
    end

    context "when the run was rate limited" do
      let(:execution) { source_execution(status: :rate_limited) }

      it { is_expected.to fail_a_policy(:source_has_input) }
    end

    context "when a non-manual trigger has no recorded input" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |builder|
            builder.node "trigger-1", "trigger:schedule", name: "Hourly"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      end

      let(:execution) { source_execution(trigger_data: {}) }

      it { is_expected.to fail_a_policy(:source_has_input) }
    end

    context "when the workflow already has the maximum number of tests" do
      before do
        stub_const(DiscourseWorkflows::WorkflowTest, :MAX_PER_WORKFLOW, 1) do
          Fabricate(:discourse_workflows_workflow_test, workflow:)
        end
      end

      it do
        stub_const(DiscourseWorkflows::WorkflowTest, :MAX_PER_WORKFLOW, 1) do
          is_expected.to fail_a_policy(:within_test_limit)
        end
      end
    end

    context "when the run has an empty manual trigger input" do
      let(:execution) { source_execution(trigger_data: {}) }

      it { is_expected.to run_successfully }
    end

    context "when the source is a real run" do
      let(:execution) do
        source_execution(
          data: {
            "entries" => {
            },
            "context" => {
            },
            "node_contexts" => {
            },
            "run_data" => {
              "Call API" => [
                {
                  "run_index" => 0,
                  "status" => "success",
                  "inputs" => [{ "index" => 0, "items" => [], "item_count" => 1 }],
                  "outputs" => [
                    {
                      "index" => 0,
                      "items" => [{ "json" => { "ok" => true } }],
                      "item_count" => 1,
                      "truncated" => false,
                    },
                  ],
                },
              ],
            },
          },
        )
      end

      it "saves the trigger input, a finishes check and the recorded response" do
        expect(result).to run_successfully

        workflow_test = result[:workflow_test]
        expect(workflow_test).to have_attributes(
          name: "Test from run ##{execution.id}",
          trigger_node_id: "trigger-1",
          trigger_type: "trigger:manual",
          trigger_data: {
            "hello" => "world",
          },
          source_execution_id: execution.id,
          created_by_id: admin.id,
        )
        expect(workflow_test.checks.map { |check| check["effect"] }).to eq(["finishes"])
        expect(workflow_test.captured_outputs).to eq(
          "Call API:0" => [{ "fingerprint" => nil, "outputs" => [{ "json" => { "ok" => true } }] }],
        )
        expect(workflow_test.captured_at).to be_nil
      end
    end

    context "when the source is a preview" do
      let(:execution) do
        source_execution(
          execution_mode: :simulation,
          data: {
            "entries" => {
            },
            "context" => {
            },
            "node_contexts" => {
            },
            "run_data" => {
            },
            "simulation" => {
              "effects" => [
                {
                  "type" => "personal_message",
                  "fields" => {
                    "recipient" => "sam",
                    "title" => "Hi",
                  },
                },
                {
                  "type" => "personal_message",
                  "fields" => {
                    "recipient" => "sam",
                    "title" => "Again",
                  },
                },
              ],
            },
          },
        )
      end
      let(:params) { super().merge(name: "Welcome flow") }

      it "suggests one check per effect type after the finishes check" do
        expect(result).to run_successfully

        checks = result[:workflow_test].checks
        expect(result[:workflow_test].name).to eq("Welcome flow")
        expect(checks.map { |check| check["effect"] }).to eq(%w[finishes personal_message])
        expect(checks.last["conditions"].first).to include("field" => "recipient", "value" => "sam")
      end
    end

    context "when checks are given explicitly" do
      let(:params) { super().merge(checks: [{ effect: "nothing" }]) }

      it "uses them as is" do
        expect(result).to run_successfully
        expect(result[:workflow_test].checks.map { |check| check["effect"] }).to eq(["nothing"])
      end
    end
  end
end
