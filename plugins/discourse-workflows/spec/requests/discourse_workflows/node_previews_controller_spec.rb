# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePreviewsController do
  fab!(:admin)
  fab!(:user)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  before do
    workflow.update!(
      nodes: [
        {
          "id" => "manual",
          "type" => "trigger:manual",
          "typeVersion" => "1.0",
          "name" => "Manual",
          "parameters" => {
          },
        },
        {
          "id" => "summarize",
          "type" => "action:summarize",
          "typeVersion" => "1.0",
          "name" => "Summarize",
          "parameters" => {
            "fields_to_summarize" => {
              "values" => [
                { "aggregation" => "sum", "field" => "score", "output_field_name" => "total" },
              ],
            },
          },
        },
        {
          "id" => "create-post",
          "type" => "action:post",
          "typeVersion" => "1.0",
          "name" => "Create post",
          "parameters" => {
            "operation" => "create",
          },
        },
      ],
      connections: {
        "Manual" => {
          "main" => [[{ "node" => "Summarize", "type" => "main", "index" => 0 }]],
        },
      },
      pin_data: {
        "Manual" => [
          { "json" => { "score" => 1 } },
          { "json" => { "score" => 9 } },
          { "json" => { "score" => 5 } },
        ],
      },
    )
  end

  def preview(node_id, parameters = nil)
    post "/admin/plugins/discourse-workflows/node-previews.json",
         params: { workflow_id: workflow.id, node_id: node_id, parameters: parameters }.compact
  end

  context "when signed in as an admin" do
    before { sign_in(admin) }

    it "returns the node's output items" do
      preview("summarize")

      expect(response.status).to eq(200)
      expect(response.parsed_body["outputs"].first.map { |item| item["json"] }).to eq(
        [{ "total" => 15 }],
      )
      expect(response.parsed_body["input_count"]).to eq(3)
    end

    it "rejects a node type that is not previewable" do
      preview("create-post")

      expect(response.status).to eq(422)
    end

    it "responds with a bad request when parameters is not an object" do
      preview("summarize", "junk")

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "404s for an unknown node" do
      preview("missing")

      expect(response.status).to eq(404)
    end
  end

  context "when signed in as a regular user" do
    before { sign_in(user) }

    it "is not allowed" do
      preview("summarize")

      expect(response.status).to eq(404)
    end
  end

  context "when anonymous" do
    it "is not allowed" do
      preview("summarize")

      expect(response.status).to eq(404)
    end
  end
end
