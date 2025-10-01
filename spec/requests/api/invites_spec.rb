# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "invites" do
  let(:"Api-Key") { Fabricate(:api_key).key }
  let(:"Api-Username") { "system" }

  path "/invites.json" do
    post "Create an invite" do
      tags "Invites"
      operationId "createInvite"
      consumes "application/json"
      parameter name: "Api-Key", in: :header, type: :string, required: true
      parameter name: "Api-Username", in: :header, type: :string, required: true
      expected_request_schema = load_spec_schema("invite_create_request")
      parameter name: :params, in: :body, schema: expected_request_schema

      produces "application/json"
      response "200", "success response" do
        expected_response_schema = load_spec_schema("invite_create_response")
        schema expected_response_schema

        let(:params) { { email: "not-a-user-yet@example.com" } }
        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
