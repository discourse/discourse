# frozen_string_literal: true
require 'swagger_helper'

describe 'invites' do

  let(:'Api-Key') { Fabricate(:api_key).key }
  let(:'Api-Username') { 'system' }

  path '/invites.json' do
    post 'Invite to site by email' do
      tags 'Invites'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true

      parameter name: :request_body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          group_names: { type: :string },
          custom_message: { type: :string },
        }, required: ['email']
      }

      produces 'application/json'
      response '200', 'success response' do
        schema type: :object, properties: {
          success: { type: :string, example: "OK" }
        }

        let(:request_body) { { email: 'not-a-user-yet@example.com' } }
        run_test!
      end
    end
  end
end
