# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhooksController do
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

  describe "POST /workflows/webhooks/:path" do
    it "enqueues workflow execution for matching webhook" do
      post "/workflows/webhooks/my-hook.json",
           params: { foo: "bar" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be(true)

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"][0]["trigger_node_id"]).to eq("webhook-1")

      trigger_data = job["args"][0]["trigger_data"]
      expect(trigger_data).to include(
        "body" => {
          "foo" => "bar",
        },
        "query" => be_a(Hash),
        "headers" => include("content-type" => "application/json"),
      )
    end

    it "returns 404 when no matching webhook exists" do
      post "/workflows/webhooks/unknown-path.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when HTTP method does not match" do
      get "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when workflow is disabled" do
      workflow.update!(enabled: false)
      post "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.discourse_workflows_enabled = false
      post "/workflows/webhooks/my-hook.json"
      expect(response.status).to eq(404)
    end

    it "works without authentication" do
      post "/workflows/webhooks/my-hook.json",
           params: { data: "test" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)
    end

    it "passes query parameters in trigger data" do
      post "/workflows/webhooks/my-hook.json?source=github&ref=main",
           params: {}.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["query"]).to include("source" => "github", "ref" => "main")
    end

    it "handles different HTTP methods" do
      workflow.update!(
        nodes:
          workflow.nodes.map do |n|
            if n["id"] == "webhook-1"
              n.merge("configuration" => { "path" => "my-hook", "http_method" => "PUT" })
            else
              n
            end
          end,
      )

      put "/workflows/webhooks/my-hook.json",
          params: { updated: true }.to_json,
          headers: {
            "CONTENT_TYPE" => "application/json",
          }

      expect(response.status).to eq(200)
    end

    it "rate limits webhook requests" do
      RateLimiter.enable

      stub_const(DiscourseWorkflows::WebhooksController, "WEBHOOK_RATE_LIMIT", 1) do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response.status).to eq(200)

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response.status).to eq(429)
      end
    ensure
      RateLimiter.disable
    end

    it "returns 400 for malformed JSON body" do
      post "/workflows/webhooks/my-hook.json",
           headers: {
             "RAW_POST_DATA" => "not valid json{",
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(400)
    end

    it "handles non-JSON content type" do
      post "/workflows/webhooks/my-hook.json", params: { data: "test" }

      expect(response.status).to eq(200)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["body"]).to eq({ "data" => "test" })
    end

    context "when resuming a waiting webhook" do
      let(:resume_token) { "resume-token" }

      before do
        extra =
          build_workflow_graph do |g|
            g.node "wait-1", "action:wait"
            g.chain "webhook-1", "wait-1"
          end
        workflow.update!(
          nodes: workflow.nodes + extra[:nodes],
          connections: extra[:connections],
        )
      end

      fab!(:waiting_execution) do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          trigger_node_id: "webhook-1",
          waiting_node_id: "wait-1",
          waiting_config: {
            "resume_token" => "resume-token",
            "wait_type" => "webhook",
            "http_method" => "POST",
            "response_mode" => "immediately",
            "webhook_suffix" => "after-approval",
          },
        )
      end

      before do
        Fabricate(
          :discourse_workflows_execution_data,
          execution: waiting_execution,
          workflow_data: DiscourseWorkflows::WorkflowSnapshot.snapshot(workflow),
        )
      end

      it "resumes when the suffix matches" do
        post "/workflows/webhooks/#{waiting_execution.id}/after-approval.json?token=#{resume_token}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq(true)

        job = Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.last
        expect(job["args"].first).to include("execution_id" => waiting_execution.id)
        expect(job["args"].first["response_items"].first["json"]["webhook_url"]).to eq(
          "#{Discourse.base_url}/workflows/webhooks/#{waiting_execution.id}/after-approval?token=#{resume_token}",
        )
      end

      it "returns 404 when the suffix does not match" do
        post "/workflows/webhooks/#{waiting_execution.id}/wrong-suffix.json?token=#{resume_token}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(404)
      end

      it "redirects when the resumed workflow responds to webhook with a redirect" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://example.com/thanks",
                   }
            g.connect "wait-1", "respond-1"
          end
        workflow.update!(
          nodes: workflow.nodes + extra[:nodes],
          connections: workflow.connections + extra[:connections],
        )

        waiting_execution.execution_data.update!(
          workflow_data: DiscourseWorkflows::WorkflowSnapshot.snapshot(workflow),
        )

        waiting_execution.update!(
          waiting_config:
            waiting_execution.waiting_config.merge("response_mode" => "respond_to_webhook"),
        )

        post "/workflows/webhooks/#{waiting_execution.id}/after-approval.json?token=#{resume_token}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(302)
        expect(response.headers["Location"]).to eq("https://example.com/thanks")
      end
    end

    describe "synchronous response modes" do
      def setup_webhook_with_response(response_mode:, target_node_id:, extra:, webhook_config: {})
        workflow.update!(
          nodes:
            workflow.nodes.map do |n|
              if n["id"] == "webhook-1"
                n.merge(
                  "configuration" => {
                    "path" => "my-hook",
                    "http_method" => "POST",
                    "response_mode" => response_mode,
                  }.merge(webhook_config),
                )
              else
                n
              end
            end + extra[:nodes],
          connections: [
            {
              "source_node_id" => "webhook-1",
              "target_node_id" => target_node_id,
              "source_output" => "main",
            },
          ],
        )
      end

      it "redirects when respond_to_webhook node produces a redirect" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://example.com/thanks",
                   }
          end
        setup_webhook_with_response(
          response_mode: "respond_to_webhook",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(302)
        expect(response.headers["Location"]).to eq("https://example.com/thanks")
      end

      it "returns JSON when respond_to_webhook node produces JSON" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "json",
                     "status_code" => "201",
                     "response_body" => '{"created": true}',
                   }
          end
        setup_webhook_with_response(
          response_mode: "respond_to_webhook",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(201)
        expect(response.parsed_body).to eq("created" => true)
      end

      it "returns text when respond_to_webhook node produces text" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "text",
                     "status_code" => "200",
                     "response_body" => "OK thanks",
                   }
          end
        setup_webhook_with_response(
          response_mode: "respond_to_webhook",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(200)
        expect(response.body).to eq("OK thanks")
      end

      it "returns no data response" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "no_data",
                     "status_code" => "204",
                   }
          end
        setup_webhook_with_response(
          response_mode: "respond_to_webhook",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(204)
      end

      it "returns last node output as JSON when mode is when_last_node_finishes" do
        extra =
          build_workflow_graph do |g|
            g.node "set-fields-1",
                   "action:set_fields",
                   configuration: {
                     "mode" => "json",
                     "json" => '{"result": "done"}',
                   }
          end
        setup_webhook_with_response(
          response_mode: "when_last_node_finishes",
          target_node_id: "set-fields-1",
          extra: extra,
          webhook_config: {
            "response_code" => "200",
          },
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to be_a(Hash)
      end
    end

    context "with basic auth webhook" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "basic_auth",
          data:
            DiscourseWorkflows::CredentialEncryptor.encrypt(
              { "user" => "hook_user", "password" => "hook_pass" },
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
                    "response_mode" => "immediately",
                    "authentication" => "basic_auth",
                    "credential_id" => credential.id,
                  },
                )
              else
                n
              end
            end,
        )
      end

      it "returns 401 with WWW-Authenticate when no auth header" do
        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(401)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Webhook"')
      end

      it "returns 200 with valid credentials" do
        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("hook_user:hook_pass")}",
             }

        expect(response.status).to eq(200)
      end
    end
  end
end
