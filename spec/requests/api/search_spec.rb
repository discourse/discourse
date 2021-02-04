# frozen_string_literal: true
require 'swagger_helper'

describe 'groups' do

  let(:admin) { Fabricate(:admin) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/search.json' do
    get 'Search for a term' do
      tags 'Search'
      consumes 'application/json'
      expected_request_schema = load_spec_schema('search_request')
      parameter name: :params, in: :body, schema: expected_request_schema

      produces 'application/json'
      response '200', 'success response' do
        expected_response_schema = load_spec_schema('search_response')
        schema expected_response_schema

        let(:params) { { 'q' => 'awesome post' } }

        it_behaves_like "a JSON endpoint", 200 do
          let(:expected_response_schema) { expected_response_schema }
          let(:expected_request_schema) { expected_request_schema }
        end
      end
    end
  end
end
