# frozen_string_literal: true
require "swagger_helper"

RSpec.describe "multiple invites" do
  let(:"Api-Key") { Fabricate(:api_key).key }
  let(:"Api-Username") { "system" }

  path "/invites/create-multiple.json" do
    post "Create multiple invites" do
      tags "Invites"
      operationId "createMultipleInvites"
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
                      example: %w[not-a-user-yet-1@example.com not-a-user-yet-2@example.com],
                      description:
                        "pass 1 email per invite to be generated. other properties will be shared by each invite.",
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
                    group_ids: {
                      type: :string,
                      description:
                        "Optional, either this or `group_names`. Comma separated list for multiple ids.",
                      example: "42,43",
                    },
                    group_names: {
                      type: :string,
                      description:
                        "Optional, either this or `group_ids`. Comma separated list for multiple names.",
                      example: "foo,bar",
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
                 num_successfully_created_invitations: {
                   type: :integer,
                   example: 42,
                 },
                 num_failed_invitations: {
                   type: :integer,
                   example: 42,
                 },
                 failed_invitations: {
                   type: :array,
                   items: {
                   },
                   example: [],
                 },
                 successful_invitations: {
                   type: :array,
                   example: [
                     {
                       id: 42,
                       link: "http://example.com/invites/9045fd767efe201ca60c6658bcf14158",
                       email: "not-a-user-yet-1@example.com",
                       emailed: true,
                       custom_message: "Hello world!",
                       topics: [],
                       groups: [],
                       created_at: "2021-01-01T12:00:00.000Z",
                       updated_at: "2021-01-01T12:00:00.000Z",
                       expires_at: "2021-02-01T12:00:00.000Z",
                       expired: false,
                     },
                     {
                       id: 42,
                       link: "http://example.com/invites/c6658bcf141589045fd767efe201ca60",
                       email: "not-a-user-yet-2@example.com",
                       emailed: true,
                       custom_message: "Hello world!",
                       topics: [],
                       groups: [],
                       created_at: "2021-01-01T12:00:00.000Z",
                       updated_at: "2021-01-01T12:00:00.000Z",
                       expires_at: "2021-02-01T12:00:00.000Z",
                       expired: false,
                     },
                   ],
                 },
               }

        let(:request_body) do
          { email: %w[not-a-user-yet-1@example.com not-a-user-yet-2@example.com] }
        end
        run_test!
      end
    end
  end
end
