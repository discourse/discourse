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
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
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
      let(:response_mode) { "on_received" }
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
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      let(:waiting_execution) do
        execution = DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
        execution.update!(resume_token: resume_token)
        execution
      end

      let(:signature) do
        DiscourseWorkflows::WaitingExecution.resume_signature(
          execution_id: waiting_execution.id,
          resume_token: resume_token,
        )
      end

      let(:params) do
        {
          execution_id: waiting_execution.id,
          token: signature,
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

        it { is_expected.to fail_a_policy(:valid_http_method) }
      end

      context "when response mode is on_received" do
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
              DiscourseWorkflows::WaitingExecution.webhook_url(
                execution_id: waiting_execution.id,
                resume_token: resume_token,
              ),
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

        it { is_expected.to fail_a_policy(:valid_resume_request) }
      end

      context "when token does not match" do
        let(:params) { super().merge(token: "wrong-token") }

        it { is_expected.to fail_a_policy(:valid_resume_request) }
      end

      context "when response mode is synchronous" do
        let(:response_mode) { "last_node" }
        let(:response_code) { "200" }

        fab!(:resumed_execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

        before { DiscourseWorkflows::Executor.stubs(:resume).returns(resumed_execution) }

        it { is_expected.to run_successfully }

        it "sets sync_result on the context" do
          expect(result[:sync_result][:execution]).to eq(resumed_execution)
          expect(result[:sync_result][:response_mode]).to eq("last_node")
          expect(result[:sync_result][:response_code]).to eq("200")
        end

        context "when the execution has already been claimed for resume" do
          before do
            allow(DiscourseWorkflows::Execution).to receive(:claim_for_resume).and_return(nil)
          end

          it { is_expected.to fail_to_find_a_model(:claimed_execution) }
        end
      end
    end

    context "when triggering new workflows" do
      before { publish_workflow!(workflow) }

      context "when path does not match any webhook node" do
        let(:params) { super().merge(path: "unknown") }

        it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
      end

      context "when HTTP method does not match" do
        let(:params) { super().merge(http_method: "GET") }

        it { is_expected.to fail_to_find_a_model(:webhook_nodes) }
      end

      context "when workflow is unpublished" do
        before { unpublish_workflow!(workflow) }

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
              "params" => {
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

      context "with an IP allowlist" do
        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              "parameters" => node["parameters"].merge("ip_allowlist" => "not-an-ip, 127.0.0.1"),
            )
          end
          publish_workflow!(workflow)
        end

        let(:params) { super().merge(remote_ip: "127.0.0.1") }

        it "ignores invalid entries when another entry matches" do
          result
          job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
          expect(job["args"].first["trigger_node_id"]).to eq("webhook-1")
        end
      end

      context "with basic auth" do
        fab!(:credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "basic_auth",
            data: {
              "user" => "webhook_user",
              "password" => "webhook_pass",
            },
          )
        end

        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              DiscourseWorkflows::NodeData.split(
                parameters: {
                  "path" => "my-hook",
                  "http_method" => "POST",
                  "authentication" => "basic_auth",
                },
                credentials: {
                  "auth" => {
                    "id" => credential.id,
                    "credential_type" => "basic_auth",
                  },
                },
                node_type: node["type"],
              ),
            )
          end
          publish_workflow!(workflow)
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

          it "exposes :denied as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:denied)
            expect(result[:auth_failure_mode]).to eq("basic_auth")
          end
        end

        context "when request has no authorization header" do
          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }

          it "exposes :challenge as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:challenge)
            expect(result[:auth_failure_mode]).to eq("basic_auth")
          end
        end

        context "when credential record is missing" do
          before { credential.destroy! }

          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }

          it "exposes :misconfigured as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:misconfigured)
          end
        end

        context "when auth mode is unsupported" do
          before do
            update_workflow_node(workflow, "webhook-1") do |node|
              node.merge(
                "parameters" => node["parameters"].merge("authentication" => "unknown_mode"),
              )
            end
            publish_workflow!(workflow)
          end

          it { is_expected.to fail_to_find_a_model(:authenticated_nodes) }

          it "exposes :misconfigured as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:misconfigured)
          end
        end
      end

      context "with bearer auth" do
        fab!(:credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "bearer_token",
            data: {
              "token" => "secret-token",
            },
          )
        end

        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              DiscourseWorkflows::NodeData.split(
                parameters: {
                  "path" => "my-hook",
                  "http_method" => "POST",
                  "authentication" => "bearer_auth",
                },
                credentials: {
                  "auth" => {
                    "id" => credential.id,
                    "credential_type" => "bearer_token",
                  },
                },
                node_type: node["type"],
              ),
            )
          end
          publish_workflow!(workflow)
        end

        context "when request has valid bearer token" do
          let(:params) do
            auth = "Bearer secret-token"
            super().merge(headers: { "authorization" => auth }, raw_authorization: auth)
          end

          it { is_expected.to run_successfully }
        end

        context "when bearer token is missing" do
          it "exposes :denied as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:denied)
          end
        end
      end

      context "with header auth" do
        fab!(:credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "header_auth",
            data: {
              "name" => "X-Api-Key",
              "value" => "secret-value",
            },
          )
        end

        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              DiscourseWorkflows::NodeData.split(
                parameters: {
                  "path" => "my-hook",
                  "http_method" => "POST",
                  "authentication" => "header_auth",
                },
                credentials: {
                  "auth" => {
                    "id" => credential.id,
                    "credential_type" => "header_auth",
                  },
                },
                node_type: node["type"],
              ),
            )
          end
          publish_workflow!(workflow)
        end

        context "when request has matching header" do
          let(:params) { super().merge(headers: { "x-api-key" => "secret-value" }) }

          it { is_expected.to run_successfully }
        end

        context "when header is missing" do
          it "exposes :denied as the auth failure reason" do
            expect(result[:auth_failure_reason]).to eq(:denied)
          end
        end
      end

      context "when another workflow tries to claim the same path" do
        fab!(:conflicting_workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "other-webhook-1",
                     "trigger:webhook",
                     configuration: {
                       "path" => "my-hook",
                       "http_method" => "POST",
                       "authentication" => "none",
                     }
            end
          Fabricate(:discourse_workflows_workflow, created_by: admin, published: false, **graph)
        end

        it "rejects activation of the second workflow with CollisionError" do
          publish_workflow!(workflow)

          expect { publish_workflow!(conflicting_workflow) }.to raise_error(
            DiscourseWorkflows::Webhook::Action::ActivateWebhooks::CollisionError,
          )
        end
      end

      context "with synchronous response mode" do
        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              "parameters" =>
                node["parameters"].merge("response_mode" => "last_node", "response_code" => "201"),
            )
          end
          publish_workflow!(workflow)
        end

        it { is_expected.to run_successfully }

        it "does not enqueue an async job" do
          result
          expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
        end

        it "sets sync_result on the context" do
          expect(result[:sync_result][:execution]).to be_a(DiscourseWorkflows::Execution)
          expect(result[:sync_result][:response_mode]).to eq("last_node")
          expect(result[:sync_result][:response_code]).to eq("201")
        end
      end
    end

    context "when triggering a test webhook" do
      let(:test_listener_id) { nil }
      let(:params) { super().merge(test_webhook: true, test_listener_id: test_listener_id) }

      before { unpublish_workflow!(workflow) }

      context "when no listener is active" do
        it { is_expected.to fail_to_find_a_model(:webhook_test_listener) }
      end

      context "when everything is valid" do
        let(:listener) do
          DiscourseWorkflows::WebhookTestListener.create!(
            workflow: workflow,
            user: admin,
            trigger_node: workflow.find_node("webhook-1"),
          )
        end
        let(:test_listener_id) { listener.listener_id }

        it { is_expected.to run_successfully }

        it "runs the draft workflow synchronously" do
          expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)

          execution = DiscourseWorkflows::Execution.last
          expect(execution).to have_attributes(
            workflow_id: workflow.id,
            trigger_node_id: "webhook-1",
            execution_mode: "manual",
            status: "success",
          )
          expect(execution.trigger_data["webhook_url"]).to eq(
            "#{Discourse.base_url}/workflows/webhook-test/#{listener.listener_id}/my-hook",
          )
        end

        it "does not enqueue an async job" do
          result

          expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
        end
      end

      context "when request filtering rejects the request" do
        let(:listener) do
          DiscourseWorkflows::WebhookTestListener.create!(
            workflow: workflow,
            user: admin,
            trigger_node: workflow.find_node("webhook-1"),
          )
        end
        let(:test_listener_id) { listener.listener_id }

        before do
          workflow.update!(
            nodes:
              workflow.nodes.map do |node|
                next node unless node["id"] == "webhook-1"

                node.merge("parameters" => node["parameters"].merge("ip_allowlist" => "127.0.0.1"))
              end,
          )
        end

        let(:params) { super().merge(remote_ip: "192.0.2.10") }

        it { is_expected.to fail_to_find_a_model(:request_allowed_nodes) }

        it "does not consume the listener" do
          result

          expect(
            DiscourseWorkflows::WebhookTestListener.find_by_route(method: "POST", path: "my-hook"),
          ).to be_present
        end
      end
    end
  end
end
