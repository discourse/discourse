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
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  describe "POST /workflows/webhooks/:path" do
    it "enqueues workflow execution for matching webhook" do
      post "/workflows/webhooks/my-hook.json",
           params: { foo: "bar" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:ok)
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
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when HTTP method does not match" do
      get "/workflows/webhooks/my-hook.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when workflow is unpublished" do
      unpublish_workflow!(workflow)
      post "/workflows/webhooks/my-hook.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.enable_discourse_workflows = false
      post "/workflows/webhooks/my-hook.json"
      expect(response).to have_http_status(:not_found)
    end

    it "works without authentication" do
      post "/workflows/webhooks/my-hook.json",
           params: { data: "test" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:ok)
    end

    it "passes query parameters in trigger data" do
      post "/workflows/webhooks/my-hook.json?source=github&ref=main",
           params: {}.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:ok)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["query"]).to include("source" => "github", "ref" => "main")
    end

    it "handles different HTTP methods" do
      update_workflow_node(workflow, "webhook-1") do |node|
        node.merge("parameters" => { "path" => "my-hook", "http_method" => "PUT" })
      end
      publish_workflow!(workflow)

      put "/workflows/webhooks/my-hook.json",
          params: { updated: true }.to_json,
          headers: {
            "CONTENT_TYPE" => "application/json",
          }

      expect(response).to have_http_status(:ok)
    end

    it "matches dynamic paths and exposes captured params in trigger data" do
      dynamic_graph =
        build_workflow_graph do |g|
          g.node "webhook-1",
                 "trigger:webhook",
                 webhook_id: "abcd-1234",
                 configuration: {
                   "path" => "users/:id/posts",
                   "http_method" => "POST",
                 }
        end
      dynamic_workflow =
        Fabricate(
          :discourse_workflows_workflow,
          created_by: admin,
          published: true,
          **dynamic_graph,
        )
      publish_workflow!(dynamic_workflow)

      post "/workflows/webhooks/abcd-1234/users/42/posts.json",
           params: {}.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:ok)
      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["params"]).to eq("id" => "42")
    end

    it "rate limits webhook requests" do
      RateLimiter.enable

      stub_const(DiscourseWorkflows::WebhooksController, "WEBHOOK_RATE_LIMIT", 1) do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response).to have_http_status(:ok)

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response).to have_http_status(:too_many_requests)
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

      expect(response).to have_http_status(:bad_request)
    end

    it "handles non-JSON content type" do
      post "/workflows/webhooks/my-hook.json", params: { data: "test" }

      expect(response).to have_http_status(:ok)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["body"]).to eq({ "data" => "test" })
    end

    context "when receiving test webhooks" do
      def start_webhook_test_listener
        DiscourseWorkflows::WebhookTestListener.create!(
          workflow: workflow,
          user: admin,
          trigger_node: workflow.find_node("webhook-1"),
        )
      end

      before { unpublish_workflow!(workflow) }

      it "returns 404 when no listener exists" do
        post "/workflows/webhook-test/my-hook.json",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:not_found)
      end

      it "executes the draft workflow for the first matching request" do
        listener = start_webhook_test_listener

        expect do
          post "#{listener.test_url}.json?source=test",
               params: { foo: "bar" }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        end.to change { DiscourseWorkflows::Execution.count }.by(1)

        expect(response).to have_http_status(:ok)
        execution = DiscourseWorkflows::Execution.last
        expect(execution).to have_attributes(
          workflow_id: workflow.id,
          trigger_node_id: "webhook-1",
          execution_mode: "manual",
          status: "success",
        )
        expect(execution.trigger_data).to include(
          "body" => {
            "foo" => "bar",
          },
          "query" => {
            "source" => "test",
          },
          "method" => "POST",
          "webhook_url" => "#{Discourse.base_url}#{listener.test_url}",
        )
      end

      it "consumes the listener after the first matching request" do
        listener = start_webhook_test_listener

        2.times do
          post "#{listener.test_url}.json",
               params: {}.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        end

        expect(response).to have_http_status(:not_found)
      end

      it "does not consume the listener when HTTP method does not match" do
        listener = start_webhook_test_listener

        get "#{listener.test_url}.json"
        expect(response).to have_http_status(:not_found)

        post "#{listener.test_url}.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response).to have_http_status(:ok)
      end

      it "does not consume the listener without the listener id in the URL" do
        listener = start_webhook_test_listener

        post "/workflows/webhook-test/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response).to have_http_status(:not_found)

        post "#{listener.test_url}.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 after the listener is cancelled" do
        listener = start_webhook_test_listener
        DiscourseWorkflows::WebhookTestListener.cancel!(listener)

        post "#{listener.test_url}.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when resuming a waiting webhook" do
      let(:resume_token) { "resume-token" }
      let(:signature) do
        DiscourseWorkflows::WaitingExecution.resume_signature(
          execution_id: waiting_execution.id,
          resume_token: resume_token,
        )
      end

      before do
        extra =
          build_workflow_graph do |g|
            g.node "wait-1",
                   "flow:wait",
                   configuration: {
                     "http_method" => "POST",
                     "response_mode" => "on_received",
                     "webhook_suffix" => "after-approval",
                   }
            g.chain "webhook-1", "wait-1"
          end
        nodes = workflow.nodes + extra[:nodes]
        workflow.update!(
          nodes: nodes,
          connections: workflow_connections_for(nodes, %w[webhook-1 wait-1]),
        )
      end

      fab!(:waiting_execution) do
        Fabricate(
          :discourse_workflows_execution,
          workflow: workflow,
          status: :waiting,
          trigger_node_id: "webhook-1",
          waiting_node_id: "wait-1",
          resume_token: "resume-token",
        )
      end

      before do
        Fabricate(
          :discourse_workflows_execution_data,
          execution: waiting_execution,
          workflow_data: DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow).to_h,
        )
      end

      it "resumes when the suffix matches" do
        post "/workflows/waiting/#{waiting_execution.id}/webhook/after-approval.json?signature=#{signature}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["success"]).to eq(true)

        job = Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.last
        expect(job["args"].first).to include("execution_id" => waiting_execution.id)
        expect(job["args"].first["response_items"].first["json"]["webhook_url"]).to eq(
          DiscourseWorkflows::WaitingExecution.webhook_url(
            execution_id: waiting_execution.id,
            resume_token: resume_token,
            suffix: "after-approval",
          ),
        )
      end

      it "returns 404 when the suffix does not match" do
        post "/workflows/waiting/#{waiting_execution.id}/webhook/wrong-suffix.json?signature=#{signature}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:not_found)
      end

      it "does not accept token resume requests on the public webhook path" do
        post "/workflows/webhooks/#{waiting_execution.id}/after-approval.json?token=#{resume_token}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:not_found)
      end

      it "does not accept token on the waiting resume route" do
        expect do
          post "/workflows/waiting/#{waiting_execution.id}/webhook/after-approval.json?token=#{resume_token}",
               params: { foo: "bar" }.to_json,
               headers: {
                 "CONTENT_TYPE" => "application/json",
               }
        end.not_to change { Jobs::DiscourseWorkflows::ResumeWebhookWaiting.jobs.size }

        expect(response).to have_http_status(:not_found)
      end

      it "redirects when the resumed workflow responds to webhook with a redirect" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://example.com/thanks",
                     "allowed_redirect_domains" => {
                       "values" => [{ "domain" => "example.com" }],
                     },
                   }
            g.connect "wait-1", "respond-1"
          end
        updated_nodes =
          (workflow.nodes + extra[:nodes]).map do |n|
            if n["id"] == "wait-1"
              n.merge(
                "parameters" => (n["parameters"] || {}).merge("response_mode" => "response_node"),
              )
            else
              n
            end
          end
        workflow.update!(
          nodes: updated_nodes,
          connections: workflow_connections_for(updated_nodes, %w[wait-1 respond-1]),
        )

        waiting_execution.execution_data.update!(
          workflow_data: DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow).to_h,
        )

        post "/workflows/waiting/#{waiting_execution.id}/webhook/after-approval.json?signature=#{signature}",
             params: { foo: "bar" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:found)
        expect(response.headers["Location"]).to eq("https://example.com/thanks")
      end
    end

    describe "synchronous response modes" do
      def setup_webhook_with_response(response_mode:, target_node_id:, extra:, webhook_config: {})
        nodes =
          workflow_nodes_with_update(workflow, "webhook-1") do |node|
            node.merge(
              "parameters" => {
                "path" => "my-hook",
                "http_method" => "POST",
                "response_mode" => response_mode,
              }.merge(webhook_config),
            )
          end + extra[:nodes]

        workflow.update!(
          nodes: nodes,
          connections: workflow_connections_for(nodes, ["webhook-1", target_node_id]),
        )
        publish_workflow!(workflow)
      end

      it "redirects when respond_to_webhook node produces a redirect" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://example.com/thanks",
                     "allowed_redirect_domains" => {
                       "values" => [{ "domain" => "example.com" }],
                     },
                   }
          end
        setup_webhook_with_response(
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:found)
        expect(response.headers["Location"]).to eq("https://example.com/thanks")
      end

      it "rejects external redirect responses when the domain is not allowed" do
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
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to eq("invalid_redirect_url")
      end

      it "allows wildcard subdomain redirect responses" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://docs.example.com/thanks",
                     "allowed_redirect_domains" => {
                       "values" => [{ "domain" => "*.example.com" }],
                     },
                   }
          end
        setup_webhook_with_response(
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:found)
        expect(response.headers["Location"]).to eq("https://docs.example.com/thanks")
      end

      it "does not allow wildcard domains to match the root domain" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "redirect",
                     "redirect_url" => "https://example.com/thanks",
                     "allowed_redirect_domains" => {
                       "values" => [{ "domain" => "*.example.com" }],
                     },
                   }
          end
        setup_webhook_with_response(
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to eq("invalid_redirect_url")
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
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to eq("created" => true)
      end

      it "returns JSON null when respond_to_webhook node produces null" do
        extra =
          build_workflow_graph do |g|
            g.node "respond-1",
                   "action:respond_to_webhook",
                   configuration: {
                     "response_type" => "json",
                     "status_code" => "200",
                     "response_body" => "null",
                   }
          end
        setup_webhook_with_response(
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("null")
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
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:ok)
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
          response_mode: "response_node",
          target_node_id: "respond-1",
          extra: extra,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:no_content)
      end

      it "returns last node output as JSON when mode is last_node" do
        extra =
          build_workflow_graph do |g|
            g.node "set-fields-1",
                   "action:set_fields",
                   configuration: {
                     "mode" => "raw",
                     "json_output" => '{"result": "done"}',
                   }
          end
        setup_webhook_with_response(
          response_mode: "last_node",
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

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_a(Hash)
      end
    end

    context "with basic auth webhook" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "basic_auth",
          data: {
            "user" => "hook_user",
            "password" => "hook_pass",
          },
        )
      end

      before do
        update_workflow_node(workflow, "webhook-1") do |node|
          node.merge(
            "parameters" => {
              "path" => "my-hook",
              "http_method" => "POST",
              "response_mode" => "on_received",
              "authentication" => "basic_auth",
            },
            "credentials" => {
              "auth" => {
                "id" => credential.id.to_s,
                "credential_type" => "basic_auth",
              },
            },
          )
        end
        publish_workflow!(workflow)
      end

      it "returns 401 with WWW-Authenticate and plain text body when no auth header" do
        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Webhook"')
        expect(response.media_type).to eq("text/plain")
        expect(response.body).to eq("Authorization is required!")
      end

      it "returns 403 with WWW-Authenticate when credentials are wrong" do
        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("wrong:creds")}",
             }

        expect(response).to have_http_status(:forbidden)
        expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Webhook"')
        expect(response.body).to eq("Authorization data is wrong!")
      end

      it "returns 500 without WWW-Authenticate when credential is missing" do
        credential.destroy!

        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:internal_server_error)
        expect(response.headers["WWW-Authenticate"]).to be_nil
        expect(response.body).to eq("No authentication data defined on node!")
      end

      it "returns 200 with valid credentials" do
        post "/workflows/webhooks/my-hook.json",
             params: { data: "test" }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("hook_user:hook_pass")}",
             }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with bearer auth webhook" do
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
            "parameters" => {
              "path" => "my-hook",
              "http_method" => "POST",
              "response_mode" => "on_received",
              "authentication" => "bearer_auth",
            },
            "credentials" => {
              "auth" => {
                "id" => credential.id.to_s,
                "credential_type" => "bearer_token",
              },
            },
          )
        end
        publish_workflow!(workflow)
      end

      it "returns 403 without WWW-Authenticate when no bearer token" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:forbidden)
        expect(response.headers["WWW-Authenticate"]).to be_nil
      end

      it "returns 403 when bearer token is wrong" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_AUTHORIZATION" => "Bearer wrong-token",
             }

        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 with valid bearer token" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_AUTHORIZATION" => "Bearer secret-token",
             }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with header auth webhook" do
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
            "parameters" => {
              "path" => "my-hook",
              "http_method" => "POST",
              "response_mode" => "on_received",
              "authentication" => "header_auth",
            },
            "credentials" => {
              "auth" => {
                "id" => credential.id.to_s,
                "credential_type" => "header_auth",
              },
            },
          )
        end
        publish_workflow!(workflow)
      end

      it "returns 403 without WWW-Authenticate when header is missing" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response).to have_http_status(:forbidden)
        expect(response.headers["WWW-Authenticate"]).to be_nil
      end

      it "returns 403 when header value is wrong" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_X_API_KEY" => "wrong-value",
             }

        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 with correct header value" do
        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "HTTP_X_API_KEY" => "secret-value",
             }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
