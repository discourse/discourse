# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DynamicNodeParametersController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "POST /admin/plugins/discourse-workflows/dynamic-node-parameters/options" do
    fab!(:badge) { Fabricate(:badge, name: "Helpful") }
    fab!(:group_1) { Fabricate(:group, name: "alpha") }

    it "returns options for a known load options method" do
      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:badge",
               version: "1.0",
             },
             path: "badge_id",
             methodName: "badges",
             currentNodeParameters: {
             },
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => badge.id, "name" => badge.name)
    end

    it "returns groups for the group node" do
      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:group",
               version: "1.0",
             },
             path: "group_id",
             methodName: "groups",
             currentNodeParameters: {
             },
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => group_1.id, "name" => group_1.name)
    end

    it "returns 404 for an unknown node type" do
      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:unknown",
               version: "1.0",
             },
             path: "badge_id",
             methodName: "badges",
           },
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown load options method" do
      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:badge",
               version: "1.0",
             },
             path: "badge_id",
             methodName: "nonexistent",
           },
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "passes compatible dynamic parameter context to context-aware nodes" do
      credential =
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "basic_auth",
          data: {
            "user" => "static-user",
            "password" => "static-password",
          },
        )
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:load_options_context_test",
            credentials: [
              {
                name: "auth",
                credential_types: %w[basic_auth],
                display_options: {
                  show: {
                    authentication: %w[basic_auth],
                  },
                },
              },
            ],
          )

          def self.load_options_context(context)
            [
              {
                id: context.get_current_node_parameter("operation"),
                name: context.filter,
                method_name: context.method_name,
                property_name: context.property_name,
                workflow_id: context.workflow_id,
                credential_slots: context.credentials.keys,
                credential_user: context.get_credentials("auth")["user"],
                node_id: context.node_id,
                input_subject: context.input_context.dig("item", "json", "subject"),
                execution_value: context.execution_context.dig("preview", "value"),
                user_id: context.user.id,
              },
            ]
          end
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(node_class, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!

      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:load_options_context_test",
               version: "1.0",
             },
             path: "thing_id",
             methodName: "things",
             currentNodeParameters: {
               authentication: "basic_auth",
               operation: "list",
             },
             credentials: {
               auth: {
                 id: credential.id,
                 credential_type: "basic_auth",
               },
               ignored: {
                 id: credential.id,
                 credential_type: "basic_auth",
               },
             },
             node: {
               id: "node-1",
               name: "Context test",
             },
             workflowId: "42",
             inputContext: {
               item: {
                 json: {
                   subject: "From input item",
                 },
               },
             },
             executionContext: {
               preview: {
                 value: "from-preview",
               },
             },
             filter: "alp",
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        "id" => "list",
        "name" => "alp",
        "method_name" => "things",
        "property_name" => "thing_id",
        "workflow_id" => "42",
        "credential_slots" => ["auth"],
        "credential_user" => "static-user",
        "node_id" => "node-1",
        "input_subject" => "From input item",
        "execution_value" => "from-preview",
        "user_id" => admin.id,
      )
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      DiscourseWorkflows::Registry.reset_indexes!
    end

    it "uses the requested node version when loading options" do
      v1 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:load_options_version_test", version: "1.0")

          def self.load_options_context(_context)
            [{ id: "v1", name: "Version 1" }]
          end
        end
      v2 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:load_options_version_test", version: "2.0")

          def self.load_options_context(_context)
            [{ id: "v2", name: "Version 2" }]
          end
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(v1, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(v2, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!

      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:load_options_version_test",
               version: "1.0",
             },
             path: "thing_id",
             methodName: "things",
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly("id" => "v1", "name" => "Version 1")

      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:load_options_version_test",
               version: "2.0",
             },
             path: "thing_id",
             methodName: "things",
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly("id" => "v2", "name" => "Version 2")
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [v1, v2].include?(entry[:value])
      end
      DiscourseWorkflows::Registry.reset_indexes!
    end

    it "requires exact node versions when loading options" do
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:exact_load_options_version_test", version: "1.0")

          def self.load_options_context(_context)
            [{ id: "v1", name: "Version 1" }]
          end
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(node_class, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!

      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:exact_load_options_version_test",
               version: 1,
             },
             path: "thing_id",
             methodName: "things",
           },
           as: :json

      expect(response).to have_http_status(:not_found)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      DiscourseWorkflows::Registry.reset_indexes!
    end

    it "requires the context-aware option loader" do
      node_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(name: "action:load_options_method_test")

          def self.load_options(method_name)
            [{ id: method_name, name: method_name.upcase }]
          end
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(node_class, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!

      post "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
           params: {
             nodeTypeAndVersion: {
               name: "action:load_options_method_test",
               version: "1.0",
             },
             path: "thing_id",
             methodName: "things",
           },
           as: :json

      expect(response).to have_http_status(:not_found)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        entry[:value] == node_class
      end
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end
end
