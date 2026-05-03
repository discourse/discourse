# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypesController do
  fab!(:admin)

  before { sign_in(admin) }

  context "when not logged in as admin" do
    fab!(:user)

    before { sign_in(user) }

    it "returns 404" do
      get "/admin/plugins/discourse-workflows/node-types.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /admin/plugins/discourse-workflows/node-types" do
    it "returns all registered node types" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      identifiers = json["node_types"].map { |nt| nt["identifier"] }

      expect(identifiers).to include("trigger:topic_closed")
      expect(identifiers).to include("action:topic_tags")
      expect(identifiers).to include("action:create_post")
      expect(identifiers).to include("action:create_topic")
      expect(identifiers).to include("condition:if")
    end

    it "does not include metadata key in node type response" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      badge_node =
        response.parsed_body["node_types"].find { |nt| nt["identifier"] == "action:badge" }
      expect(badge_node).not_to have_key("metadata")
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
    end
  end

  describe "GET /admin/plugins/discourse-workflows/node-types/:identifier/options/:source_key" do
    fab!(:badge) { Fabricate(:badge, name: "Helpful") }
    fab!(:group_1) { Fabricate(:group, name: "alpha") }

    it "returns options for a known source key" do
      get "/admin/plugins/discourse-workflows/node-types/action%3Abadge/options/badges.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["options"]).to include("id" => badge.id, "name" => badge.name)
    end

    it "returns groups for the group node" do
      get "/admin/plugins/discourse-workflows/node-types/action%3Agroup/options/groups.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["options"]).to include("id" => group_1.id, "name" => group_1.name)
    end

    it "returns 404 for an unknown node type" do
      get "/admin/plugins/discourse-workflows/node-types/action%3Aunknown/options/badges.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 for an unknown source key" do
      get "/admin/plugins/discourse-workflows/node-types/action%3Abadge/options/nonexistent.json"
      expect(response.status).to eq(404)
    end
  end
end
