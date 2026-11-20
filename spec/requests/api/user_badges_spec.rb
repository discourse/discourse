# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "user_badges" do
  let(:admin) { Fabricate(:admin) }
  let(:badge) { Fabricate(:badge) }
  let(:user) { Fabricate(:user) }
  let(:associated_post) { Fabricate(:post) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path "/user_badges.json" do
    post "Grant a badge to a user" do
      tags "Badges", "Users"
      operationId "grantUserBadge"
      consumes "application/json"
      expected_request_schema = load_spec_schema("user_badge_grant_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "badge granted" do
        expected_response_schema = nil
        let(:params) do
          { "username" => user.username, "badge_id" => badge.id, "post_id" => associated_post.id }
        end

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
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
