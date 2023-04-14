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

      parameter name: :request_body,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    email: {
                      type: :string,
                      example: "not-a-user-yet@example.com",
                      description: "required for email invites only",
                    },
                    skip_email: {
                      type: :boolean,
                      default: false,
                    },
                    custom_message: {
                      type: :string,
                      description: "optional, for email invites",
                    },
                    max_redemptions_allowed: {
                      type: :integer,
                      example: 5,
                      default: 1,
                      description: "optional, for link invites",
                    },
                    topic_id: {
                      type: :integer,
                    },
                    group_id: {
                      type: :integer,
                      description: "optional, either this or `group_names`",
                    },
                    group_names: {
                      type: :string,
                      description: "optional, either this or `group_id`",
                    },
                    expires_at: {
                      type: :string,
                      description:
                        "optional, if not supplied, the invite_expiry_days site setting is used",
                    },
                  },
                }

      produces "application/json"
      response "200", "success response" do
        schema type: :object,
               properties: {
                 id: {
                   type: :integer,
                   example: 42,
                 },
                 link: {
                   type: :string,
                   example: "http://example.com/invites/9045fd767efe201ca60c6658bcf14158",
                 },
                 email: {
                   type: :string,
                   example: "not-a-user-yet@example.com",
                 },
                 emailed: {
                   type: :boolean,
                   example: false,
                 },
                 custom_message: {
                   type: %i[string null],
                   example: "Hello world!",
                 },
                 topics: {
                   type: :array,
                   items: {
                   },
                   example: [],
                 },
                 groups: {
                   type: :array,
                   items: {
                   },
                   example: [],
                 },
                 created_at: {
                   type: :string,
                   example: "2021-01-01T12:00:00.000Z",
                 },
                 updated_at: {
                   type: :string,
                   example: "2021-01-01T12:00:00.000Z",
                 },
                 expires_at: {
                   type: :string,
                   example: "2021-02-01T12:00:00.000Z",
                 },
                 expired: {
                   type: :boolean,
                   example: false,
                 },
               }

        let(:request_body) { { email: "not-a-user-yet@example.com" } }
        run_test!
      end
    end
  end
end
