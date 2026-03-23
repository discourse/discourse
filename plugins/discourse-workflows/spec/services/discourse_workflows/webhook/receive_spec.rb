# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Receive do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true) }
    fab!(:webhook_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:webhook",
        name: "Webhook",
        configuration: {
          "path" => "my-hook",
          "http_method" => "POST",
        },
      )
    end

    before { SiteSetting.discourse_workflows_enabled = true }

    let(:params) do
      {
        path: "my-hook",
        http_method: "POST",
        body: {
          "foo" => "bar",
        },
        headers: {
          "content-type" => "application/json",
        },
        query_params: {
          "source" => "test",
        },
      }
    end

    context "when path does not match any webhook node" do
      let(:params) { super().merge(path: "unknown") }

      it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
    end

    context "when http method does not match" do
      let(:params) { super().merge(http_method: "GET") }

      it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "enqueues an ExecuteWorkflow job with correct arguments" do
        result
        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include(
          "trigger_node_id" => webhook_node.id,
          "trigger_data" => {
            "body" => {
              "foo" => "bar",
            },
            "headers" => {
              "content-type" => "application/json",
            },
            "query" => {
              "source" => "test",
            },
            "method" => "POST",
            "webhook_url" => "#{Discourse.base_url}/workflows/webhooks/my-hook",
          },
        )
      end
    end
  end
end
