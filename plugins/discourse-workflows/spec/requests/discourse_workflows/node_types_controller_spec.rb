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
    it "returns all registered node types" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      identifiers = json["node_types"].map { |nt| nt["identifier"] }

      expect(identifiers).to include("trigger:topic_closed")
      expect(identifiers).to include("action:topic_tags")
      expect(identifiers).to include("action:post")
      expect(identifiers).to include("action:topic")
      expect(identifiers).to include("action:group")
      expect(identifiers).to include("condition:if")
      expect(identifiers).to include("action:send_personal_message")
      expect(identifiers).not_to include("condition:user_in_group")
    end

    it "returns Post operation and List posts query control metadata" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      post_node =
        response.parsed_body["node_types"].find do |node_type|
          node_type["identifier"] == "action:post"
        end
      properties = post_node["properties"]

      expect(properties["operation"]).to include(
        "type" => "options",
        "default" => "create",
        "options" => %w[create edit get list],
      )
      expect(properties["query"]).to include(
        "type" => "string",
        "ui" => include("control" => "filter_query", "filter" => "posts"),
      )
      expect(properties["editor_username"]).to include(
        "type" => "string",
        "default" => "system",
        "ui" => include("control" => "actor"),
      )
      expect(properties["whisper"]).to include(
        "type" => "boolean",
        "default" => false,
        "ui" => include("control" => "boolean", "expression" => true),
        "display_options" => include("show" => include("operation" => ["create"])),
      )
      expect(properties["categories"]["ui"]).to include("hidden" => true)
      expect(properties["advanced_filter"]["ui"]).to include("hidden" => true)
    end

    it "returns Send personal message recipient control metadata" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      personal_message_node =
        response.parsed_body["node_types"].find do |node_type|
          node_type["identifier"] == "action:send_personal_message"
        end
      properties = personal_message_node["properties"]

      expect(properties["recipient_usernames"]).to include(
        "type" => "array",
        "ui" => include("control" => "user", "expression" => true, "multiple" => true),
      )
      expect(properties["recipient_group_names"]).to include(
        "type" => "array",
        "type_options" => include("load_options_method" => "groups"),
        "ui" => include("control" => "group_select", "expression" => true, "multiple" => true),
        "control_options" =>
          include("value_property" => "name", "name_property" => "name", "filterable" => true),
      )
      expect(properties["sender_username"]).to include(
        "type" => "string",
        "default" => "system",
        "ui" => include("control" => "actor"),
      )
      expect(personal_message_node.dig("metadata", "groups")).to include(
        include("id" => Group::AUTO_GROUPS[:everyone], "name" => "everyone"),
      )
    end

    it "includes load options metadata in node type response" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      badge_node =
        response.parsed_body["node_types"].find { |nt| nt["identifier"] == "action:badge" }
      expect(badge_node.dig("metadata", "badges")).to all(include("id", "name"))

      group_node =
        response.parsed_body["node_types"].find { |nt| nt["identifier"] == "action:group" }
      expect(group_node.dig("metadata", "groups")).to include(
        include("id" => Group::AUTO_GROUPS[:everyone], "name" => "everyone"),
      )
      expect(group_node.dig("properties", "group_id", "type_options")).not_to include(
        "load_options_depends_on",
      )
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

    it "returns descriptor fields used by the admin client" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      condition =
        response.parsed_body["node_types"].find do |node_type|
          node_type["identifier"] == "condition:if"
        end

      expect(condition["ui"]["palette_group"]).to include("id" => "flow")
      expect(condition["capabilities"]).to include(
        "branching" => true,
        "manually_triggerable" => false,
        "result_mode" => "ports",
      )
      expect(condition["ports"]).to include(
        a_hash_including(
          "key" => "true",
          "label_key" => "discourse_workflows.branch.true",
          "primary" => true,
        ),
      )
      expect(condition["inputs"]).to include(a_hash_including("key" => "main", "required" => true))
    end
  end
end
