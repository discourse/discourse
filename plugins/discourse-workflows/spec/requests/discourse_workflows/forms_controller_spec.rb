# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormsController do
  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:form",
               configuration: {
                 "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
                 "form_title" => "Test Form",
                 "form_fields" => [
                   { "field_label" => "Name", "field_type" => "text", "required" => true },
                 ],
                 "response_mode" => "on_received",
               }
      end
    Fabricate(:discourse_workflows_workflow, enabled: true, **graph)
  end

  let(:origin_headers) { { "Origin" => "http://#{Discourse.current_hostname}" } }

  describe "GET /workflows/form/:uuid.json" do
    it "returns form schema" do
      get "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["form_title"]).to eq("Test Form")
      expect(json["form_fields"].length).to eq(1)
    end

    it "returns 404 for unknown uuid" do
      get "/workflows/form/00000000-0000-0000-0000-000000000000.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 for disabled workflow" do
      workflow.update!(enabled: false)
      get "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json"
      expect(response.status).to eq(404)
    end

    context "when the form requires a logged-in user" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["authentication"] = "login_required"
        workflow.update!(nodes: workflow.nodes)
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "returns 403 for anonymous users" do
        get "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json"
        expect(response.status).to eq(403)
      end

      it "returns form schema for logged-in users" do
        sign_in(Fabricate(:user))
        get "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "POST /workflows/form/:uuid.json" do
    it "executes workflow and returns resume token" do
      post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
           params: {
             form_data: {
               name: "Test User",
             },
           },
           headers: origin_headers
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["resume_token"]).to be_present

      execution = DiscourseWorkflows::Execution.last
      expect(execution.trigger_node_id).to eq("trigger-1")
      expect(execution.execution_data.context_data["__resume_token"]).to eq(json["resume_token"])
    end

    it "returns 422 with missing field labels when required fields are omitted" do
      post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
           params: {
             form_data: {
             },
           },
           headers: origin_headers
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(["Name"])
    end

    context "when the form requires a logged-in user" do
      before do
        trigger_node = workflow.nodes.find { |n| n["type"] == "trigger:form" }
        trigger_node["configuration"]["authentication"] = "login_required"
        workflow.update!(nodes: workflow.nodes)
        DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow)
      end

      it "returns 403 for anonymous users" do
        post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
             params: {
               form_data: {
                 name: "Test User",
               },
             },
             headers: origin_headers
        expect(response.status).to eq(403)
      end

      it "executes workflow for logged-in users" do
        sign_in(Fabricate(:user))
        post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
             params: {
               form_data: {
                 name: "Test User",
               },
             },
             headers: origin_headers
        expect(response.status).to eq(200)
      end
    end
  end

  describe "PUT /workflows/form/:uuid.json" do
    it "returns 404 when no waiting execution matches the resume token" do
      put "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
          params: {
            resume_token: "nonexistent-token",
          },
          headers: origin_headers
      expect(response.status).to eq(404)
    end

    it "returns 422 when resume_token is missing" do
      put "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
          params: {
            form_data: {
            },
          },
          headers: origin_headers
      expect(response.status).to eq(422)
    end

    context "with a workflow containing a downstream form action" do
      before do
        extra =
          build_workflow_graph do |g|
            g.node "form-action-1",
                   "action:form",
                   name: "Second Page",
                   configuration: {
                     "page_type" => "page",
                     "form_fields" => [
                       { "field_label" => "Email", "field_type" => "text", "required" => false },
                     ],
                   }
            g.node "form-completion-1",
                   "action:form",
                   name: "Completion",
                   configuration: {
                     "page_type" => "completion",
                     "on_submission" => "completion_screen",
                     "completion_title" => "Done",
                     "completion_message" => "Thanks",
                   }
          end
        workflow.update!(
          nodes: workflow.nodes + extra[:nodes],
          connections: [
            {
              "source_node_id" => "trigger-1",
              "target_node_id" => "form-action-1",
              "source_output" => "main",
            },
            {
              "source_node_id" => "form-action-1",
              "target_node_id" => "form-completion-1",
              "source_output" => "main",
            },
          ],
        )
      end

      it "resumes a waiting execution and returns a new resume token" do
        post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
             params: {
               form_data: {
                 name: "Test User",
               },
             },
             headers: origin_headers
        expect(response.status).to eq(200)

        resume_token = response.parsed_body["resume_token"]
        expect(resume_token).to be_present

        execution = DiscourseWorkflows::Execution.last
        expect(execution.status).to eq("waiting")
        expect(execution.waiting_node_id).to eq("form-action-1")

        put "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
            params: {
              resume_token: resume_token,
              form_data: {
                email: "test@example.com",
              },
            },
            headers: origin_headers
        expect(response.status).to eq(200)

        execution.reload
        expect(execution.status).to eq("success")
      end

      it "returns 404 when execution has already been resumed" do
        post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
             params: {
               form_data: {
                 name: "Test User",
               },
             },
             headers: origin_headers
        resume_token = response.parsed_body["resume_token"]

        put "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
            params: {
              resume_token: resume_token,
              form_data: {
                email: "test@example.com",
              },
            },
            headers: origin_headers
        expect(response.status).to eq(200)

        put "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
            params: {
              resume_token: resume_token,
              form_data: {
                email: "test@example.com",
              },
            },
            headers: origin_headers
        expect(response.status).to eq(404)
      end
    end
  end
end
