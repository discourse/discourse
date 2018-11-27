require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe 'Multisite s3 uploads', type: :multisite do
  let(:conn) { RailsMultisite::ConnectionManagement }
  let(:store) { FileStore::S3Store.new }
  let(:s3_helper) { store.instance_variable_get(:@s3_helper) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  before(:each) do
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.enable_s3_uploads = true
  end

  shared_context 's3 helpers' do
    let(:store) { FileStore::S3Store.new }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:resource) { Aws::S3::Resource.new(client: client) }
    let(:s3_bucket) { resource.bucket("s3-upload-bucket") }
    let(:s3_helper) { store.instance_variable_get(:@s3_helper) }
  end

  context 'uploading to s3' do
    include_context "s3 helpers"

    describe "#store_upload" do
      it "returns the correct url for default multisite db" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        s3_object = stub
        upload = Fabricate(:upload, sha1: Digest::SHA1.hexdigest('secreet image string'))

        conn.with_connection('default') do
          s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:upload_file)

          expect(store.store_upload(uploaded_file, upload)).to eq(
          "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/original/1X/#{upload.sha1}.png"
          )
        end
      end

      it "returns the correct url for second multisite db" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        s3_object = stub
        upload = Fabricate(:upload, sha1: Digest::SHA1.hexdigest('secreet second string'))

        conn.with_connection('second') do
          s3_bucket.expects(:object).with("uploads/second/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:upload_file)

          expect(store.store_upload(uploaded_file, upload)).to eq(
          "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/uploads/second/original/1X/#{upload.sha1}.png"
          )
        end
      end
    end
  end
end
