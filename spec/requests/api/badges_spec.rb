# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "badges" do
  fab!(:admin)
  fab!(:badge)

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/admin/badges.json" do
    get "List badges" do
      tags "Badges"
      operationId "adminListBadges"
      consumes "application/json"
      expected_request_schema = nil

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("badge_list_response")
        schema expected_response_schema

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    post "Create badge" do
      tags "Badges"
      operationId "createBadge"
      consumes "application/json"
      expected_request_schema = load_spec_schema("badge_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("badge_create_response")
        schema expected_response_schema

        let(:params) { { "name" => "badge1", "badge_type_id" => 2 } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end

  path "/admin/badges/{id}.json" do
    put "Update badge" do
      tags "Badges"
      operationId "updateBadge"
      consumes "application/json"
      expected_request_schema = load_spec_schema("badge_update_request")
      parameter name: :id, in: :path, schema: { type: :integer }
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("badge_update_response")
        schema expected_response_schema

        let(:id) { badge.id }

        let(:params) { { "name" => "badge1", "badge_type_id" => 2 } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end

    delete "Delete badge" do
      tags "Badges"
      operationId "deleteBadge"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :id, in: :path, schema: { type: :integer }

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = nil
        schema expected_response_schema

        let(:id) { badge.id }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
