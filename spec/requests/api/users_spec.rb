# frozen_string_literal: true
require 'swagger_helper'

describe 'users' do

  let(:'Api-Key') { Fabricate(:api_key).key }
  let(:'Api-Username') { 'system' }

  path '/users.json' do

    post 'Creates a user' do
      tags 'Users'
      consumes 'application/json'
      parameter name: 'Api-Key', in: :header, type: :string, required: true
      parameter name: 'Api-Username', in: :header, type: :string, required: true
      parameter name: :user_body, in: :body, schema: {
        type: :object,
        properties: {
          "name": { type: :string },
          "email": { type: :string },
          "password": { type: :string },
          "username": { type: :string },
          "active": { type: :boolean },
          "approved": { type: :boolean },
          "user_fields[1]": { type: :string },
        },
        required: ['name', 'email', 'password', 'username']
      }

      produces 'application/json'
      response '200', 'user created' do
        schema type: :object, properties: {
          success: { type: :boolean },
          active: { type: :boolean },
          message: { type: :string },
          user_id: { type: :integer },
        }

        let(:user_body) { {
          name: 'user',
          username: 'user1',
          email: 'user1@example.com',
          password: '13498428e9597cab689b468ebc0a5d33',
          active: true
        } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to eq(true)
          expect(data['active']).to eq(true)
        end
      end
    end

  end
end
