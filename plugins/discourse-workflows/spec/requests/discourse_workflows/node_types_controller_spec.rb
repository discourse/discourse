# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypesController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/node-types.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/node-types" do
    it "renders the registered node types", :aggregate_failures do
      get "/admin/plugins/discourse-workflows/node-types.json"

      expect(response).to have_http_status(:ok)
      identifiers = response.parsed_body["node_types"].map { |nt| nt["identifier"] }
      expect(identifiers).to include("trigger:topic_closed", "action:post", "condition:if")
      expect(identifiers).not_to include("condition:user_in_group")
    end

    it "does not preload load options metadata that depends on node parameters" do
      topic = Fabricate(:topic)
      TopicCustomField.create!(topic: topic, name: "workflow_key", value: "value")

      get "/admin/plugins/discourse-workflows/node-types.json"

      topic_node =
        response.parsed_body["node_types"].find { |nt| nt["identifier"] == "action:topic" }

      expect(topic_node.dig("properties", "custom_field_names", "type_options")).to include(
        "load_options_depends_on",
      )
      expect(topic_node.fetch("metadata", {})).not_to have_key("topic_custom_fields")
    end

    it "returns Site setting action metadata without hidden or secret settings" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      node =
        response.parsed_body["node_types"].find do |node_type|
          node_type["identifier"] == "action:site_setting"
        end
      properties = node["properties"]

      expect(properties["name"]).to include(
        "type" => "string",
        "required" => true,
        "type_options" => include("load_options_method" => "site_settings"),
        "ui" => include("control" => "combo_box"),
      )
      expect(properties["value"]).to include("type" => "string")
      expect(properties["actor_username"]).to include("ui" => include("control" => "actor"))

      option_ids = node.dig("metadata", "site_settings").map { |option| option["id"] }
      expect(option_ids).to include("site_description")
      expect(option_ids).not_to include(SiteSetting.secret_settings.first.to_s)
      expect(option_ids).not_to include(SiteSetting.hidden_settings.first.to_s)
      expect(node.dig("output_contracts", 0, "schema", "properties")).to include(
        "name" => include("type" => "string"),
        "changed" => include("type" => "boolean"),
      )
    end
  end
end
