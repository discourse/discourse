# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Receive do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:http_method) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "webhook-1",
                 "trigger:webhook",
                 configuration: {
                   "path" => "my-hook",
                   "http_method" => "POST",
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
    end

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

    context "when contract is invalid" do
      let(:params) { { http_method: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when resuming a waiting execution" do
      let(:resume_token) { "my-hook" }
      let(:webhook_suffix) { "" }
      let(:response_mode) { "immediately" }
      let(:response_code) { "200" }
      let(:wait_http_method) { "POST" }

      let(:waiting_workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "wait-1",
                   "flow:wait",
                   configuration: {
                     "resume" => "webhook",
                     "http_method" => wait_http_method,
                     "response_mode" => response_mode,
                     "response_code" => response_code,
                     "webhook_suffix" => webhook_suffix,
                   }
            g.chain "trigger-1", "wait-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
      end

      let(:waiting_execution) do
        execution = DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
        execution.update!(resume_token: resume_token)
        execution
      end

      let(:params) do
        {
          execution_id: waiting_execution.id,
          token: resume_token,
          webhook_suffix: webhook_suffix,
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

      context "when HTTP method does not match waiting execution" do
        let(:params) { super().merge(http_method: "GET") }

        it { is_expected.to fail_a_step(:validate_waiting_http_method) }
      end

      context "when response mode is immediately" do
        it { is_expected.to run_successfully }

        it "enqueues a ResumeWebhookWaiting job" do
          result
          job = Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.last
          expect(job["args"].first).to include("execution_id" => waiting_execution.id)
          expect(job["args"].first["response_items"].first["json"]).to include(
            "body" => {
              "foo" => "bar",
            },
            "method" => "POST",
            "webhook_url" =>
              "#{Discourse.base_url}/workflows/webhooks/#{waiting_execution.id}?token=#{resume_token}",
          )
        end
      end

      context "when waiting execution expects a webhook suffix" do
        let(:webhook_suffix) { "after-approval" }

        it { is_expected.to run_successfully }
      end

      context "when webhook suffix does not match" do
        let(:webhook_suffix) { "after-approval" }
        let(:params) { super().merge(webhook_suffix: "wrong-suffix") }

        it { is_expected.to fail_a_step(:validate_resume_request) }
      end

      context "when token does not match" do
        let(:params) { super().merge(token: "wrong-token") }

        it { is_expected.to fail_a_step(:validate_resume_request) }
      end

      context "when response mode is synchronous" do
        let(:response_mode) { "when_last_node_finishes" }
        let(:response_code) { "200" }

        fab!(:resumed_execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

        before { DiscourseWorkflows::Executor.stubs(:resume).returns(resumed_execution) }

        it { is_expected.to run_successfully }

        it "sets sync execution on the context" do
          expect(result[:sync_execution]).to eq(resumed_execution)
          expect(result[:sync_response_mode]).to eq("when_last_node_finishes")
          expect(result[:sync_response_code]).to eq("200")
        end
      end
    end

    context "when triggering new workflows" do
      before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

      context "when path does not match any webhook node" do
        let(:params) { super().merge(path: "unknown") }

        it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
      end

      context "when HTTP method does not match" do
        let(:params) { super().merge(http_method: "GET") }

        it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
      end

      context "when workflow is disabled" do
        before { workflow.update!(enabled: false) }

        it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
      end

      context "when everything is valid" do
        it { is_expected.to run_successfully }

        it "enqueues an ExecuteWorkflow job" do
          result
          job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
          expect(job["args"].first).to include(
            "trigger_node_id" => "webhook-1",
            "workflow_id" => workflow.id,
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

      context "with basic auth" do
        fab!(:credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "basic_auth",
            data:
              DiscourseWorkflows::CredentialEncryptor.encrypt(
                { "user" => "webhook_user", "password" => "webhook_pass" },
              ),
          )
        end

        before do
          workflow.update!(
            nodes:
              workflow.nodes.map do |n|
                if n["id"] == "webhook-1"
                  n.merge(
                    "configuration" => {
                      "path" => "my-hook",
                      "http_method" => "POST",
                      "authentication" => "basic_auth",
                      "credential_id" => credential.id,
                    },
                  )
                else
                  n
                end
              end,
          )
          DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
        end

        context "when request has valid basic auth" do
          let(:params) do
            auth = "Basic #{Base64.strict_encode64("webhook_user:webhook_pass")}"
            super().merge(headers: { "authorization" => auth }, raw_authorization: auth)
          end

          it { is_expected.to run_successfully }

          it "executes the workflow" do
            result
            job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
            expect(job["args"].first["trigger_node_id"]).to eq("webhook-1")
          end
        end

        context "when request has wrong credentials" do
          let(:params) do
            auth = "Basic #{Base64.strict_encode64("wrong:creds")}"
            super().merge(headers: { "authorization" => auth }, raw_authorization: auth)
          end

          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }
        end

        context "when request has no authorization header" do
          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }
        end

        context "when credential record is missing" do
          before { credential.destroy! }

          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }
        end

        context "when auth mode is unsupported" do
          before do
            workflow.update!(
              nodes:
                workflow.nodes.map do |n|
                  if n["id"] == "webhook-1"
                    n.merge(
                      "configuration" =>
                        n["configuration"].merge("authentication" => "bearer_token"),
                    )
                  else
                    n
                  end
                end,
            )
          end

          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }
        end
      end

      context "with mixed auth nodes on same path" do
        fab!(:credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "basic_auth",
            data:
              DiscourseWorkflows::CredentialEncryptor.encrypt(
                { "user" => "webhook_user", "password" => "webhook_pass" },
              ),
          )
        end

        fab!(:unprotected_workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "unprotected-webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "my-hook",
                       "http_method" => "POST",
                       "authentication" => "none",
                     }
            end
          Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)
        end

        before do
          workflow.update!(
            nodes:
              workflow.nodes.map do |n|
                if n["id"] == "webhook-1"
                  n.merge(
                    "configuration" => {
                      "path" => "my-hook",
                      "http_method" => "POST",
                      "authentication" => "basic_auth",
                      "credential_id" => credential.id,
                    },
                  )
                else
                  n
                end
              end,
          )
          DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
          DiscourseWorkflows::WorkflowDependencyIndexer.call(unprotected_workflow)
        end

        context "when request has no auth" do
          it "only executes unprotected node" do
            result
            node_ids =
              Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |j|
                j["args"].first["trigger_node_id"]
              end
            expect(node_ids).to contain_exactly("unprotected-webhook-1")
          end
        end

        context "when request has valid auth" do
          let(:params) do
            auth = "Basic #{Base64.strict_encode64("webhook_user:webhook_pass")}"
            super().merge(headers: { "authorization" => auth }, raw_authorization: auth)
          end

          it "executes both nodes" do
            result
            node_ids =
              Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |j|
                j["args"].first["trigger_node_id"]
              end
            expect(node_ids).to contain_exactly("webhook-1", "unprotected-webhook-1")
          end
        end
      end

      context "with synchronous response mode" do
        before do
          workflow.update!(
            nodes:
              workflow.nodes.map do |n|
                if n["id"] == "webhook-1"
                  n.merge(
                    "configuration" =>
                      n["configuration"].merge(
                        "response_mode" => "when_last_node_finishes",
                        "response_code" => "201",
                      ),
                  )
                else
                  n
                end
              end,
          )
          DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
        end

        it { is_expected.to run_successfully }

        it "does not enqueue an async job" do
          result
          expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
        end

        it "sets sync execution on the context" do
          expect(result[:sync_execution]).to be_a(DiscourseWorkflows::Execution)
          expect(result[:sync_response_mode]).to eq("when_last_node_finishes")
          expect(result[:sync_response_code]).to eq("201")
        end
      end
    end
  end
end
