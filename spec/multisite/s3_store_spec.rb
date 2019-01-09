require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe 'Multisite s3 uploads', type: :multisite do
  let(:uploaded_file) { file_from_fixtures("smallest.png") }
  let(:upload_sha1) { Digest::SHA1.hexdigest(File.read(uploaded_file)) }
  let(:upload) { Fabricate(:upload, sha1: upload_sha1) }

  context 'uploading to s3' do
    before(:each) do
      SiteSetting.s3_upload_bucket = "some-really-cool-bucket"
      SiteSetting.s3_access_key_id = "s3-access-key-id"
      SiteSetting.s3_secret_access_key = "s3-secret-access-key"
      SiteSetting.enable_s3_uploads = true
    end

    describe "#store_upload" do
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:s3_helper) { S3Helper.new(SiteSetting.s3_upload_bucket, '', client: s3_client) }
      let(:store) { FileStore::S3Store.new(s3_helper) }

      it "returns the correct url for default and second multisite db" do
        test_multisite_connection('default') do
          test_upload = Fabricate(:upload, sha1: upload_sha1)
          expect(store.store_upload(uploaded_file, test_upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/uploads/default/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
          expect(upload.etag).to eq("ETag")
        end

        test_multisite_connection('second') do
          test_upload = Fabricate(:upload, sha1: upload_sha1)
          expect(store.store_upload(uploaded_file, test_upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/uploads/second/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
          expect(upload.etag).to eq("ETag")
        end
      end
    end
  end

  context 'removal from s3' do
    before do
      SiteSetting.s3_region = 'us-west-1'
      SiteSetting.s3_upload_bucket = "s3-upload-bucket"
      SiteSetting.s3_access_key_id = "s3-access-key-id"
      SiteSetting.s3_secret_access_key = "s3-secret-access-key"
      SiteSetting.enable_s3_uploads = true
    end

    describe "#remove_upload" do
      let(:store) { FileStore::S3Store.new }
      let(:client) { Aws::S3::Client.new(stub_responses: true) }
      let(:resource) { Aws::S3::Resource.new(client: client) }
      let(:s3_bucket) { resource.bucket(SiteSetting.s3_upload_bucket) }
      let(:s3_helper) { store.s3_helper }

      it "removes the file from s3 on multisite" do
        test_multisite_connection('default') do
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          upload.update_attributes!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/uploads/default/original/1X/#{upload.sha1}.png")
          s3_object = stub

          s3_bucket.expects(:object).with("uploads/tombstone/default/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/uploads/default/original/1X/#{upload.sha1}.png")
          s3_bucket.expects(:object).with("uploads/default/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:delete)

          store.remove_upload(upload)
        end
      end

      it "removes the file from s3 on another multisite db" do
        test_multisite_connection('second') do
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          upload.update_attributes!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/uploads/second/original/1X/#{upload.sha1}.png")
          s3_object = stub

          s3_bucket.expects(:object).with("uploads/tombstone/second/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/uploads/second/original/1X/#{upload.sha1}.png")
          s3_bucket.expects(:object).with("uploads/second/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:delete)

          store.remove_upload(upload)
        end
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "removes the file from s3 on multisite" do
          test_multisite_connection('default') do
            store.expects(:get_depth_for).with(upload.id).returns(0)
            s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
            upload.update_attributes!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/discourse-uploads/uploads/default/original/1X/#{upload.sha1}.png")
            s3_object = stub

            s3_bucket.expects(:object).with("discourse-uploads/uploads/tombstone/default/original/1X/#{upload.sha1}.png").returns(s3_object)
            s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/discourse-uploads/uploads/default/original/1X/#{upload.sha1}.png")
            s3_bucket.expects(:object).with("discourse-uploads/uploads/default/original/1X/#{upload.sha1}.png").returns(s3_object)
            s3_object.expects(:delete)

            store.remove_upload(upload)
          end
        end
      end
    end
  end
end
