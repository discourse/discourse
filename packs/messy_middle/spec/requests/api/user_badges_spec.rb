# frozen_string_literal: true
require_relative "../../swagger_helper"

RSpec.describe "user_badges" do
  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/user-badges/{username}.json" do
    get "List badges for a user" do
      tags "Badges", "Users"
      operationId "listUserBadges"
      consumes "application/json"
      expected_request_schema = nil
      parameter name: :username, in: :path, schema: { type: :string }

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("user_badges_response")
        schema expected_response_schema

        let(:username) { admin.username }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
