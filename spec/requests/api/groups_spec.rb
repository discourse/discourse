# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "groups" do
  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/admin/groups.json" do
    post "Create a group" do
      tags "Groups"
      operationId "createGroup"
      consumes "application/json"
      expected_request_schema = load_spec_schema("group_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "group created" do
        expected_response_schema = load_spec_schema("group_create_response")
        schema expected_response_schema

        let(:params) { { "group" => { "name" => "awesome" } } }
        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/groups/{id}.json" do
    delete "Delete a group" do
      tags "Groups"
      operationId "deleteGroup"
      consumes "application/json"
      parameter name: :id, in: :path, type: :integer
      expected_request_schema = nil

      produces "application/json"
      response "200", "response" do
        expected_response_schema = load_spec_schema("success_ok_response")
        schema expected_response_schema

        let(:id) { Fabricate(:group).id }
        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/groups/{name}.json" do
    get "Get a group" do
      tags "Groups"
      operationId "getGroup"
      consumes "application/json"
      parameter name: :name,
                in: :path,
                type: :string,
                example: "name",
                description: "Use group name instead of id"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("group_response")
        schema expected_response_schema

        let(:name) { Fabricate(:group).name }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/groups/{id}.json" do
    put "Update a group" do
      tags "Groups"
      operationId "updateGroup"
      consumes "application/json"
      parameter name: :id, in: :path, type: :integer

      expected_request_schema = load_spec_schema("group_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        schema type: :object, properties: { success: { type: :string, example: "OK" } }

        let(:id) { Fabricate(:group).id }
        let(:params) { { "group" => { "name" => "awesome" } } }

        run_test!
      end
    end
  end

  path "/groups/by-id/{id}.json" do
    get "Get a group by id" do
      tags "Groups"
      operationId "getGroup"
      consumes "application/json"
      parameter name: :id,
                in: :path,
                type: :string,
                example: "name",
                description: "Use group name instead of id"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response (by id)" do
        expected_response_schema = load_spec_schema("group_response")
        schema expected_response_schema

        let(:id) { Fabricate(:group).id }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/groups/{name}/members.json" do
    get "List group members" do
      tags "Groups"
      operationId "listGroupMembers"
      consumes "application/json"
      parameter name: :name,
                in: :path,
                type: :string,
                example: "name",
                description: "Use group name instead of id"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("group_members_response")
        schema expected_response_schema

        let(:name) { Fabricate(:group).name }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/groups/{id}/members.json" do
    put "Add group members" do
      tags "Groups"
      operationId "addGroupMembers"
      consumes "application/json"
      parameter name: :id, in: :path, type: :integer
      expected_request_schema = load_spec_schema("group_add_members_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("group_add_members_response")
        schema expected_response_schema

        let(:id) { Fabricate(:group).id }
        let(:user) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }
        let(:usernames) { "#{user.username},#{user2.username}" }
        let(:params) { { "usernames" => usernames } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    delete "Remove group members" do
      tags "Groups"
      operationId "removeGroupMembers"
      consumes "application/json"
      parameter name: :id, in: :path, type: :integer
      expected_request_schema = load_spec_schema("group_remove_members_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("group_remove_members_response")
        schema expected_response_schema

        let(:id) { Fabricate(:group).id }
        let(:user) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }
        let(:usernames) { "#{user.username},#{user2.username}" }
        let(:params) { { "usernames" => usernames } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/groups.json" do
    get "List groups" do
      tags "Groups"
      operationId "listGroups"
      consumes "application/json"
      expected_request_schema = nil

      produces "application/json"
      response "200", "response" do
        expected_response_schema = load_spec_schema("groups_list_response")
        schema expected_response_schema

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
