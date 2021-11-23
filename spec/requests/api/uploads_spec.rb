# frozen_string_literal: true
require 'swagger_helper'

describe 'uploads' do

  let(:admin) { Fabricate(:admin) }
  let(:logo_file) { file_from_fixtures("logo.png") }
  let(:logo) { Rack::Test::UploadedFile.new(logo_file) }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  path '/uploads.json' do
    post 'Creates an upload' do
      tags 'Uploads'
      operationId 'createUpload'
      consumes 'multipart/form-data'

      expected_request_schema = load_spec_schema('upload_create_request')
      parameter name: :params, in: :body, schema: expected_request_schema

      let(:params) { {
        type: 'avatar',
        user_id: admin.id,
        synchronous: true,
        file: logo
      } }

      produces 'application/json'
      response '200', 'file uploaded' do
        expected_response_schema = load_spec_schema('upload_create_response')
        schema(expected_response_schema)

        # Skipping this test for now until https://github.com/rswag/rswag/issues/348
        # is resolved. This still allows the docs to be generated for this endpoint though.
        xit
      end

    end
  end
end
