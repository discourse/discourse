# frozen_string_literal: true

require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe 'Multisite s3 uploads', type: :multisite do
  let(:uploaded_file) { file_from_fixtures("smallest.png") }
  let(:upload_sha1) { Digest::SHA1.hexdigest(File.read(uploaded_file)) }
  let(:upload_path) { Discourse.store.upload_path }

  def build_upload
    Fabricate.build(:upload, sha1: upload_sha1, id: 1)
  end

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
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
          expect(upload.etag).to eq("ETag")
        end

        test_multisite_connection('second') do
          upload_path = Discourse.store.upload_path
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-east-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
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
          upload = build_upload
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.png")
          s3_object = stub

          s3_bucket.expects(:object).with("uploads/tombstone/default/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/#{upload_path}/original/1X/#{upload.sha1}.png")
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:delete)

          store.remove_upload(upload)
        end
      end

      it "removes the file from s3 on another multisite db" do
        test_multisite_connection('second') do
          upload = build_upload
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.png")
          s3_object = stub

          s3_bucket.expects(:object).with("uploads/tombstone/second/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/#{upload_path}/original/1X/#{upload.sha1}.png")
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.png").returns(s3_object)
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
            upload = build_upload
            store.expects(:get_depth_for).with(upload.id).returns(0)
            s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
            upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/discourse-uploads/#{upload_path}/original/1X/#{upload.sha1}.png")
            s3_object = stub

            s3_bucket.expects(:object).with("discourse-uploads/uploads/tombstone/default/original/1X/#{upload.sha1}.png").returns(s3_object)
            s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/discourse-uploads/#{upload_path}/original/1X/#{upload.sha1}.png")
            s3_bucket.expects(:object).with("discourse-uploads/#{upload_path}/original/1X/#{upload.sha1}.png").returns(s3_object)
            s3_object.expects(:delete)

            store.remove_upload(upload)
          end
        end
      end
    end
  end

  context 'secure uploads' do
    let(:store) { FileStore::S3Store.new }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:resource) { Aws::S3::Resource.new(client: client) }
    let(:s3_bucket) { resource.bucket("some-really-cool-bucket") }
    let(:s3_helper) { store.instance_variable_get(:@s3_helper) }
    let(:s3_object) { stub }

    before(:each) do
      SiteSetting.s3_upload_bucket = "some-really-cool-bucket"
      SiteSetting.s3_access_key_id = "s3-access-key-id"
      SiteSetting.s3_secret_access_key = "s3-secret-access-key"
      SiteSetting.enable_s3_uploads = true
      SiteSetting.prevent_anons_from_downloading_files = true
      SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
    end

    before do
      s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "etag"))
    end

    describe "when secure attachments are enabled" do
      it "returns signed URL with correct path" do
        test_multisite_connection('default') do
          upload = build_upload
          upload.update!(original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.pdf").returns(s3_object).at_least_once
          s3_object.expects(:presigned_url).with(:get, expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS)

          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//some-really-cool-bucket.s3.dualstack.us-east-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.pdf"
          )

          expect(store.url_for(upload)).not_to eq(upload.url)
        end
      end
    end

    describe "when secure media are enabled" do
      before do
        SiteSetting.login_required = true
        SiteSetting.secure_media = true
        s3_helper.stubs(:s3_client).returns(client)
        Discourse.stubs(:store).returns(store)
      end

      it "returns signed URL with correct path" do
        test_multisite_connection('default') do
          upload = Fabricate.build(:upload_s3, sha1: upload_sha1, id: 1)

          signed_url = Discourse.store.signed_url_for_path(upload.url)
          expect(signed_url).to match(/Amz-Expires/)
          expect(signed_url).to match("#{upload_path}")
        end

        test_multisite_connection('second') do
          upload_path = Discourse.store.upload_path
          upload = Fabricate.build(:upload_s3, sha1: upload_sha1, id: 1)

          signed_url = Discourse.store.signed_url_for_path(upload.url)
          expect(signed_url).to match(/Amz-Expires/)
          expect(signed_url).to match("#{upload_path}")
        end
      end
    end

    describe "#update_upload_ACL" do
      it "updates correct file for default and second multisite db" do
        test_multisite_connection('default') do
          upload = build_upload
          upload.update!(original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.pdf").returns(s3_object)
          s3_object.expects(:acl).returns(s3_object)
          s3_object.expects(:put).with(acl: "private").returns(s3_object)

          expect(store.update_upload_ACL(upload)).to be_truthy
        end

        test_multisite_connection('second') do
          upload_path = Discourse.store.upload_path
          upload = build_upload
          upload.update!(original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.pdf").returns(s3_object)
          s3_object.expects(:acl).returns(s3_object)
          s3_object.expects(:put).with(acl: "private").returns(s3_object)

          expect(store.update_upload_ACL(upload)).to be_truthy
        end
      end
    end
  end
end
