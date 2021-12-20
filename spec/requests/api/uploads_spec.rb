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
        'type' => 'avatar',
        'user_id' => admin.id,
        'synchronous' => true,
        'file' => logo
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
  # uploads#generate_presigned_put
  # uploads#complete_external_upload
  # uploads#create_multipart
  # uploads#batch_presign_multipart_parts
  # uploads#abort_multipart
  # uploads#complete_multipart
  describe "external and multipart uploads" do
    before do
      setup_s3
      SiteSetting.enable_direct_s3_uploads = true
    end

    path '/uploads/generate-presigned-put.json' do
      post 'Initiates a direct external upload' do
        tags 'Uploads'
        operationId 'generatePresignedPut'
        consumes 'application/json'
        description 'cotton-eye joe'

        expected_request_schema = load_spec_schema('upload_generate_presigned_put_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_generate_presigned_put_response')
          schema(expected_response_schema)

          let(:params) { {
            'file_name' => "test.png",
            'type' => "composer",
            'file_size' => 4096
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end
  end
end
