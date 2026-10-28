# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTest::Update do
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
    fab!(:workflow_test) { Fabricate(:discourse_workflows_workflow_test, workflow:) }

    let(:params) { { workflow_id: workflow.id, test_id: workflow_test.id, name: "Renamed" } }
    let(:dependencies) { { guardian: admin.guardian } }

    before { SiteSetting.discourse_workflows_tests_enabled = true }

    context "when the test belongs to another workflow" do
      let(:params) { super().merge(test_id: Fabricate(:discourse_workflows_workflow_test).id) }

      it { is_expected.to fail_to_find_a_model(:workflow_test) }
    end

    context "when a pasted response names an unknown step" do
      let(:params) { super().merge(pasted_responses: { "Nope" => { "ok" => true } }) }

      it { is_expected.to fail_a_policy(:pasted_steps_exist) }
    end

    context "when checks are invalid" do
      let(:params) { super().merge(checks: [{ effect: "chat_message" }]) }

      it { is_expected.to fail_with_an_invalid_model(:workflow_test) }
    end

    context "with a new name, checks and a pasted response" do
      let(:params) do
        super().merge(
          checks: [
            { effect: "finishes" },
            {
              effect: "http_request",
              conditions: [{ field: "url", value: "https://example.com" }],
            },
          ],
          pasted_responses: {
            "Call API" => '{"ok": true}',
          },
        )
      end

      it "stores them, wrapping the pasted body as output items, and changes the digest" do
        digest = workflow_test.definition_digest

        expect(result).to run_successfully

        workflow_test.reload
        expect(workflow_test.name).to eq("Renamed")
        expect(workflow_test.checks.map { |check| check["effect"] }).to eq(
          %w[finishes http_request],
        )
        expect(workflow_test.pasted_responses).to eq("Call API" => [{ "json" => { "ok" => true } }])
        expect(workflow_test.updated_by_id).to eq(admin.id)
        expect(workflow_test.definition_digest).not_to eq(digest)
      end
    end

    context "with a pasted array of items" do
      let(:params) { super().merge(pasted_responses: { "Call API" => [{ "a" => 1 }, "text"] }) }

      it "wraps each entry" do
        expect(result).to run_successfully
        expect(workflow_test.reload.pasted_responses["Call API"]).to eq(
          [{ "json" => { "a" => 1 } }, { "json" => { "data" => "text" } }],
        )
      end
    end
  end
end
