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
        build_workflow_graph do |builder|
          builder.node "webhook-1",
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
      let(:resume_token) { waiting_execution.resume_token }
      let(:webhook_suffix) { "" }
      let(:response_mode) { "on_received" }
      let(:response_code) { Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:ok).to_s }
      let(:wait_http_method) { "POST" }

      let(:waiting_workflow) do
        graph =
          build_workflow_graph do |builder|
            builder.node "trigger-1", "trigger:manual"
            builder.node "wait-1",
                         "flow:wait",
                         configuration: {
                           "resume" => "webhook",
                           "http_method" => wait_http_method,
                           "response_mode" => response_mode,
                           "response_code" => response_code,
                           "webhook_suffix" => webhook_suffix,
                         }
            builder.chain "trigger-1", "wait-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      let(:waiting_execution) do
        DiscourseWorkflows::Executor.new(waiting_workflow, "trigger-1", {}).run
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
        it "enqueues a ResumeWebhookWaiting job" do
          expect(result).to run_successfully
          job = Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.last
          expect(job["args"].first).to include(
            "execution_id" => waiting_execution.id,
            "resume_token" => waiting_execution.resume_token,
          )
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

        it "returns the resumed execution synchronously" do
          expect(result).to run_successfully
          expect(result[:sync_result]).to include(
            execution: waiting_execution,
            response_mode: response_mode,
            response_code: response_code,
          )
          expect(waiting_execution.reload).to be_success
        end

        it "fails when another request already claimed the execution" do
          DiscourseWorkflows::Execution.stubs(:claim_for_resume).returns(nil)

          expect(result).to fail_to_find_a_model(:claimed_execution)
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
        it "enqueues an ExecuteWorkflow job" do
          expect(result).to run_successfully
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

          it "executes the workflow" do
            expect(result).to run_successfully
            job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
            expect(job["args"].first["trigger_node_id"]).to eq("webhook-1")
          end
        end

        context "when request has wrong credentials" do
          let(:params) do
            auth = "Basic #{Base64.strict_encode64("wrong:creds")}"
            super().merge(headers: { "authorization" => auth }, raw_authorization: auth)
          end

          it "exposes :denied as the auth failure reason" do
            expect(result).to fail_to_find_a_model(:authenticated_nodes)
            expect(result[:auth_failure_reason]).to eq(:denied)
            expect(result[:auth_failure_mode]).to eq("basic_auth")
          end
        end

        context "when request has no authorization header" do
          it "exposes :challenge as the auth failure reason" do
            expect(result).to fail_to_find_a_model(:authenticated_nodes)
            expect(result[:auth_failure_reason]).to eq(:challenge)
            expect(result[:auth_failure_mode]).to eq("basic_auth")
          end
        end

        context "when credential record is missing" do
          before { credential.destroy! }

          it "exposes :misconfigured as the auth failure reason" do
            expect(result).to fail_to_find_a_model(:authenticated_nodes)
            expect(result[:auth_failure_reason]).to eq(:misconfigured)
          end
        end
      end

      context "with synchronous response mode" do
        let(:response_code) { Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(:created).to_s }

        before do
          update_workflow_node(workflow, "webhook-1") do |node|
            node.merge(
              "parameters" =>
                node["parameters"].merge(
                  "response_mode" => "last_node",
                  "response_code" => response_code,
                ),
            )
          end
          publish_workflow!(workflow)
        end

        it "returns a synchronous result without enqueuing a job" do
          expect(result).to run_successfully
          expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
          expect(result[:sync_result]).to include(
            response_mode: "last_node",
            response_code: response_code,
          )
          expect(result[:sync_result][:execution]).to have_attributes(
            workflow_id: workflow.id,
            status: "success",
          )
        end
      end
    end

    context "when triggering a test webhook" do
      let(:test_listener_id) { nil }
      let(:params) { super().merge(test_webhook: true, test_listener_id: test_listener_id) }
      let(:listener) do
        DiscourseWorkflows::WebhookTestListener.create!(
          workflow: workflow,
          user: admin,
          trigger_node: workflow.find_node("webhook-1"),
        )
      end

      before { unpublish_workflow!(workflow) }

      context "when no listener is active" do
        it { is_expected.to fail_to_find_a_model(:webhook_test_listener) }
      end

      context "when everything is valid" do
        let(:test_listener_id) { listener.listener_id }

        it "runs the draft workflow synchronously" do
          expect(result).to run_successfully
          expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty

          execution = result[:sync_result][:execution]
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
      end

      context "when request filtering rejects the request" do
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

        it "does not consume the listener" do
          expect(result).to fail_to_find_a_model(:request_allowed_nodes)

          expect(
            DiscourseWorkflows::WebhookTestListener.find_by_route(method: "POST", path: "my-hook"),
          ).to be_present
        end
      end
    end
  end
end
