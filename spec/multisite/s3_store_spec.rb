require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe 'Multisite s3 uploads', type: :multisite do
  let(:conn) { RailsMultisite::ConnectionManagement }
  let(:uploaded_file) { file_from_fixtures("smallest.png") }

  let(:upload) do
    Fabricate(:upload, sha1: Digest::SHA1.hexdigest(File.read(uploaded_file)))
  end

  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }

  let(:s3_helper) do
    S3Helper.new(SiteSetting.s3_upload_bucket, '', client: s3_client)
  end

  let(:store) { FileStore::S3Store.new(s3_helper) }

  context 'uploading to s3' do
    before(:each) do
      SiteSetting.s3_upload_bucket = "some-really-cool-bucket"
      SiteSetting.s3_access_key_id = "s3-access-key-id"
      SiteSetting.s3_secret_access_key = "s3-secret-access-key"
      SiteSetting.enable_s3_uploads = true
    end

    describe "#store_upload" do
      it "returns the correct url for default and second multisite db" do
        expect(store.store_upload(uploaded_file, upload)).to eq(
          "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
        )

        conn.with_connection('second') do
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/uploads/second/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
        end
      end
    end
  end
end
