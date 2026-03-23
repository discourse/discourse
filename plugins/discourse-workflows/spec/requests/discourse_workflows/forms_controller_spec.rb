# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::FormsController do
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true) }
  fab!(:trigger_node) do
    Fabricate(
      :discourse_workflows_node,
      workflow: workflow,
      type: "trigger:form",
      name: "Form Trigger",
      configuration: {
        "uuid" => "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
        "form_title" => "Test Form",
        "form_fields" => [{ "field_label" => "Name", "field_type" => "text", "required" => true }],
        "response_mode" => "on_received",
      },
    )
  end

  before { SiteSetting.discourse_workflows_enabled = true }

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
  end

  describe "POST /workflows/form/:uuid.json" do
    it "executes workflow and returns execution id" do
      post "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
           params: {
             form_data: {
               name: "Test User",
             },
           }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["execution_id"]).to be_present

      execution = DiscourseWorkflows::Execution.find(json["execution_id"])
      expect(execution.trigger_node_id).to eq(trigger_node.id)
    end
  end
end
