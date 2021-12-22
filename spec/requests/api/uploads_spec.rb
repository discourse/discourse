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
        description <<~HEREDOC
        Direct external uploads bypass the usual method of creating uploads
        via the POST /uploads route, and upload directly to an external provider,
        which by default is S3. This route begins the process, and will return
        a unique identifier for the external upload as well as a presigned URL
        which is where the file binary blob should be uploaded to.

        Once the upload is complete to the external service, you must call the
        POST /complete-external-upload route using the unique identifier returned
        by this route, which will create any required Upload record in the Discourse
        database and also move file from its temporary location to the final
        destination in the external storage service.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_generate_presigned_put_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_generate_presigned_put_response')
          schema(expected_response_schema)

          let(:params) { {
            'file_name' => "test.png",
            'type' => "composer",
            'file_size' => 4096,
            'metadata' => {
              'sha1-checksum' => "830869e4ed99128e4352aa72ff5b0ffc26fdc390"
            }
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end

    path '/uploads/complete-external-upload.json' do
      post 'Completes a direct external upload' do
        let(:unique_identifier) { "66e86218-80d9-4bda-b4d5-2b6def968705" }
        let!(:external_stub) { Fabricate(:external_upload_stub, created_by: admin) }
        let!(:upload) { Fabricate(:upload) }

        before do
          ExternalUploadManager.any_instance.stubs(:transform!).returns(upload)
          ExternalUploadManager.any_instance.stubs(:destroy!)
          external_stub.update(unique_identifier: unique_identifier)
        end

        tags 'Uploads'
        operationId 'completeExternalUpload'
        consumes 'application/json'
        description <<~HEREDOC
        Completes an external upload initialized with /get-presigned-put. The
        file will be moved from its temporary location in external storage to
        a final destination in the S3 bucket. An Upload record will also be
        created in the database in most cases.

        If a sha1-checksum was provided in the initial request it will also
        be compared with the uploaded file in storage to make sure the same
        file was uploaded. The file size will be compared for the same reason.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_complete_external_upload_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_create_response')
          schema(expected_response_schema)

          let(:params) { {
            'unique_identifier' => unique_identifier,
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end

    path '/uploads/create-multipart.json' do
      post 'Creates a multipart external upload' do
        before do
          ExternalUploadManager.stubs(:create_direct_multipart_upload).returns({
            external_upload_identifier: "66e86218-80d9-4bda-b4d5-2b6def968705",
            key: "temp/site/uploads/default/12345/67890.jpg",
            unique_identifier: "84x83tmxy398t3y._Q_z8CoJYVr69bE6D7f8J6Oo0434QquLFoYdGVerWFx9X5HDEI_TP_95c34n853495x35345394.d.ghQ"
          })
        end

        tags 'Uploads'
        operationId 'createMultipartUpload'
        consumes 'application/json'
        description <<~HEREDOC
        Creates a multipart upload in the external storage provider, storing
        a temporary reference to the external upload similar to /get-presigned-put.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_create_multipart_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_create_multipart_response')
          schema(expected_response_schema)

          let(:params) { {
            'file_name' => "test.png",
            'upload_type' => "composer",
            'file_size' => 4096,
            'metadata' => {
              'sha1-checksum' => "830869e4ed99128e4352aa72ff5b0ffc26fdc390"
            }
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end

    path '/uploads/batch-presign-multipart-parts.json' do
      post 'Generates batches of presigned URLs for multipart parts' do
        let(:unique_identifier) { "66e86218-80d9-4bda-b4d5-2b6def968705" }
        let!(:external_stub) { Fabricate(:multipart_external_upload_stub, created_by: admin) }
        let!(:upload) { Fabricate(:upload) }

        before do
          stub_s3_store
          external_stub.update(unique_identifier: unique_identifier)
        end

        tags 'Uploads'
        operationId 'batchPresignMultipartParts'
        consumes 'application/json'
        description <<~HEREDOC
        Multipart uploads are uploaded in chunks or parts to individual presigned
        URLs, similar to the one genreated by /generate-presigned-put. The part
        numbers provided must be between 1 and 10000. The total number of parts
        will depend on the chunk size in bytes that you intend to use to upload
        each chunk. For example a 12MB file may have 2 5MB chunks and a final
        2MB chunk, for part numbers 1, 2, and 3.

        This endpoint will return a presigned URL for each part number provided,
        which you can then use to send PUT requests for the binary chunk corresponding
        to that part. When the part is uploaded, the provider should return an
        ETag for the part, and this should be stored along with the part number,
        because this is needed to complete the multipart upload.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_batch_presign_multipart_parts_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_batch_presign_multipart_parts_response')
          schema(expected_response_schema)

          let(:params) { {
            'part_numbers' => [1, 2, 3],
            'unique_identifier' => "66e86218-80d9-4bda-b4d5-2b6def968705"
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end

    path '/uploads/abort-multipart.json' do
      post 'Abort multipart upload' do
        let(:unique_identifier) { "66e86218-80d9-4bda-b4d5-2b6def968705" }
        let!(:external_stub) { Fabricate(:multipart_external_upload_stub, created_by: admin) }
        let!(:upload) { Fabricate(:upload) }

        before do
          stub_s3_store
          external_stub.update(
            unique_identifier: unique_identifier,
            external_upload_identifier: "84x83tmxy398t3y._Q_z8CoJYVr69bE6D7f8J6Oo0434QquLFoYdGVerWFx9X5HDEI_TP_95c34n853495x35345394.d.ghQ"
          )
        end

        tags 'Uploads'
        operationId 'abortMultipart'
        consumes 'application/json'
        description <<~HEREDOC
        This endpoint aborts the multipart upload initiated with /create-multipart.
        This should be used when cancelling the upload. It does not matter if parts
        were already uploaded into the external storage provider.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_abort_multipart_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('success_ok_response')
          schema(expected_response_schema)

          let(:params) { {
            'external_upload_identifier' => "84x83tmxy398t3y._Q_z8CoJYVr69bE6D7f8J6Oo0434QquLFoYdGVerWFx9X5HDEI_TP_95c34n853495x35345394.d.ghQ"
          } }

          it_behaves_like "a JSON endpoint", 200 do
            let(:expected_response_schema) { expected_response_schema }
            let(:expected_request_schema) { expected_request_schema }
          end
        end
      end
    end

    path '/uploads/complete-multipart.json' do
      post 'Complete multipart upload' do
        let(:unique_identifier) { "66e86218-80d9-4bda-b4d5-2b6def968705" }
        let!(:external_stub) { Fabricate(:multipart_external_upload_stub, created_by: admin) }
        let!(:upload) { Fabricate(:upload) }

        before do
          ExternalUploadManager.any_instance.stubs(:transform!).returns(upload)
          ExternalUploadManager.any_instance.stubs(:destroy!)
          stub_s3_store
          external_stub.update(unique_identifier: unique_identifier)
        end

        tags 'Uploads'
        operationId 'completeMultipart'
        consumes 'application/json'
        description <<~HEREDOC
        Completes the multipart upload in the external store, and copies the
        file from its temporary location to its final location in the store.
        All of the parts must have been uploaded to the external storage provider.
        An Upload record will be completed in most cases once the file is copied
        to its final location.

        #{direct_uploads_disclaimer}
        HEREDOC

        expected_request_schema = load_spec_schema('upload_complete_multipart_request')
        parameter name: :params, in: :body, schema: expected_request_schema

        produces 'application/json'
        response '200', 'external upload initialized' do
          expected_response_schema = load_spec_schema('upload_create_response')
          schema(expected_response_schema)

          let(:params) { {
            'unique_identifier' => unique_identifier,
            'parts' => [
              {
                'part_number' => 1,
                'etag' => '0c376dcfcc2606f4335bbc732de93344'
              }
            ]
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
