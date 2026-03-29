# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Receive do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_presence_of(:http_method) }
  end

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

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when contract is invalid" do
      let(:params) { { path: nil, http_method: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when resuming a waiting execution" do
      fab!(:waiting_node) do
        Fabricate(:discourse_workflows_node, workflow: workflow, type: "action:wait", name: "Wait")
      end

      fab!(:waiting_execution) do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          trigger_node_id: webhook_node.id,
          waiting_node_id: waiting_node.id,
          waiting_config: {
            "resume_token" => "my-hook",
            "wait_type" => "webhook",
            "http_method" => "POST",
            "response_mode" => "immediately",
          },
        )
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
          )
        end
      end

      context "when response mode is synchronous" do
        let(:resumed_execution) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

        before do
          waiting_execution.update!(
            waiting_config: {
              "resume_token" => "my-hook",
              "wait_type" => "webhook",
              "http_method" => "POST",
              "response_mode" => "when_last_node_finishes",
              "response_code" => "200",
            },
          )
          DiscourseWorkflows::Executor.stubs(:resume).returns(resumed_execution)
        end

        it { is_expected.to run_successfully }

        it "sets sync execution on the context" do
          expect(result[:sync_execution]).to eq(resumed_execution)
          expect(result[:sync_response_mode]).to eq("when_last_node_finishes")
          expect(result[:sync_response_code]).to eq("200")
        end
      end
    end

    context "when triggering new workflows" do
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

      context "with basic auth" do
        fab!(:credential, :discourse_workflows_credential) do
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
          webhook_node.update!(
            configuration: {
              "path" => "my-hook",
              "http_method" => "POST",
              "authentication" => "basic_auth",
              "credential_id" => credential.id,
            },
          )
        end

        context "when request has valid basic auth" do
          let(:params) do
            super().merge(
              headers: {
                "authorization" => "Basic #{Base64.strict_encode64("webhook_user:webhook_pass")}",
              },
            )
          end

          it { is_expected.to run_successfully }

          it "executes the workflow" do
            result
            job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
            expect(job["args"].first["trigger_node_id"]).to eq(webhook_node.id)
          end
        end

        context "when request has wrong credentials" do
          let(:params) do
            super().merge(
              headers: {
                "authorization" => "Basic #{Base64.strict_encode64("wrong:creds")}",
              },
            )
          end

          it "skips the auth-protected node" do
            result
            expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
          end
        end

        context "when request has no authorization header" do
          it "skips the auth-protected node" do
            result
            expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
          end
        end

        context "when credential record is missing" do
          before { credential.destroy! }

          it "skips the node and logs error" do
            Rails.logger.expects(:warn).with(regexp_matches(/credential.*not found/i))
            result
            expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs).to be_empty
          end
        end
      end

      context "with mixed auth nodes on same path" do
        fab!(:credential, :discourse_workflows_credential) do
          Fabricate(
            :discourse_workflows_credential,
            credential_type: "basic_auth",
            data:
              DiscourseWorkflows::CredentialEncryptor.encrypt(
                { "user" => "webhook_user", "password" => "webhook_pass" },
              ),
          )
        end

        fab!(:unprotected_node) do
          Fabricate(
            :discourse_workflows_node,
            workflow: Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true),
            type: "trigger:webhook",
            name: "Unprotected Webhook",
            configuration: {
              "path" => "my-hook",
              "http_method" => "POST",
              "authentication" => "none",
            },
          )
        end

        before do
          webhook_node.update!(
            configuration: {
              "path" => "my-hook",
              "http_method" => "POST",
              "authentication" => "basic_auth",
              "credential_id" => credential.id,
            },
          )
        end

        context "when request has no auth" do
          it "only executes unprotected node" do
            result
            node_ids =
              Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |j|
                j["args"].first["trigger_node_id"]
              end
            expect(node_ids).to contain_exactly(unprotected_node.id)
          end
        end

        context "when request has valid auth" do
          let(:params) do
            super().merge(
              headers: {
                "authorization" => "Basic #{Base64.strict_encode64("webhook_user:webhook_pass")}",
              },
            )
          end

          it "executes both nodes" do
            result
            node_ids =
              Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map do |j|
                j["args"].first["trigger_node_id"]
              end
            expect(node_ids).to contain_exactly(webhook_node.id, unprotected_node.id)
          end
        end
      end
    end
  end
end
