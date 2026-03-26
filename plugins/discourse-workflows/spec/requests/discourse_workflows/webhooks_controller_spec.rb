# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhooksController do
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

  describe "POST /workflows/webhooks/:path" do
    it "enqueues workflow execution for matching webhook" do
      post "/workflows/webhooks/my-hook.json",
           params: { foo: "bar" }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)

      job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
      expect(job["args"][0]["trigger_node_id"]).to eq(webhook_node.id)

      trigger_data = job["args"][0]["trigger_data"]
      expect(trigger_data).to include(
        "body" => {
          "foo" => "bar",
        },
        "query" => be_a(Hash),
        "headers" => be_a(Hash),
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
      webhook_node.update!(configuration: { "path" => "my-hook", "http_method" => "PUT" })

      put "/workflows/webhooks/my-hook.json",
          params: { updated: true }.to_json,
          headers: {
            "CONTENT_TYPE" => "application/json",
          }

      expect(response.status).to eq(200)
    end

    it "handles non-JSON content type" do
      post "/workflows/webhooks/my-hook.json", params: { data: "test" }

      expect(response.status).to eq(200)

      trigger_data = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"][0]["trigger_data"]
      expect(trigger_data["body"]).to eq({ "data" => "test" })
    end
    describe "synchronous response modes" do
      it "redirects when respond_to_webhook node produces a redirect" do
        webhook_node.update!(
          configuration: {
            "path" => "my-hook",
            "http_method" => "POST",
            "response_mode" => "respond_to_webhook",
          },
        )

        respond_node =
          Fabricate(
            :discourse_workflows_node,
            workflow: workflow,
            type: "action:respond_to_webhook",
            name: "Respond",
            configuration: {
              "response_type" => "redirect",
              "redirect_url" => "https://example.com/thanks",
            },
          )

        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: webhook_node,
          target_node: respond_node,
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
        webhook_node.update!(
          configuration: {
            "path" => "my-hook",
            "http_method" => "POST",
            "response_mode" => "respond_to_webhook",
          },
        )

        respond_node =
          Fabricate(
            :discourse_workflows_node,
            workflow: workflow,
            type: "action:respond_to_webhook",
            name: "Respond",
            configuration: {
              "response_type" => "json",
              "status_code" => "201",
              "response_body" => '{"created": true}',
            },
          )

        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: webhook_node,
          target_node: respond_node,
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
        webhook_node.update!(
          configuration: {
            "path" => "my-hook",
            "http_method" => "POST",
            "response_mode" => "respond_to_webhook",
          },
        )

        respond_node =
          Fabricate(
            :discourse_workflows_node,
            workflow: workflow,
            type: "action:respond_to_webhook",
            name: "Respond",
            configuration: {
              "response_type" => "text",
              "status_code" => "200",
              "response_body" => "OK thanks",
            },
          )

        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: webhook_node,
          target_node: respond_node,
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
        webhook_node.update!(
          configuration: {
            "path" => "my-hook",
            "http_method" => "POST",
            "response_mode" => "respond_to_webhook",
          },
        )

        respond_node =
          Fabricate(
            :discourse_workflows_node,
            workflow: workflow,
            type: "action:respond_to_webhook",
            name: "Respond",
            configuration: {
              "response_type" => "no_data",
              "status_code" => "204",
            },
          )

        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: webhook_node,
          target_node: respond_node,
        )

        post "/workflows/webhooks/my-hook.json",
             params: {}.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }

        expect(response.status).to eq(204)
      end

      it "returns last node output as JSON when mode is when_last_node_finishes" do
        webhook_node.update!(
          configuration: {
            "path" => "my-hook",
            "http_method" => "POST",
            "response_mode" => "when_last_node_finishes",
            "response_code" => "200",
          },
        )

        set_fields_node =
          Fabricate(
            :discourse_workflows_node,
            workflow: workflow,
            type: "action:set_fields",
            name: "SetFields",
            configuration: {
              "mode" => "json",
              "json" => '{"result": "done"}',
            },
          )

        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: webhook_node,
          target_node: set_fields_node,
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
  end
end
