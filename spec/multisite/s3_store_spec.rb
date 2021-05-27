# frozen_string_literal: true

require 'rails_helper'
require 'file_store/s3_store'

RSpec.describe 'Multisite s3 uploads', type: :multisite do
  let(:original_filename) { "smallest.png" }
  let(:uploaded_file) { file_from_fixtures(original_filename) }
  let(:upload_sha1) { Digest::SHA1.hexdigest(File.read(uploaded_file)) }
  let(:upload_path) { Discourse.store.upload_path }

  def build_upload
    Fabricate.build(:upload, sha1: upload_sha1, id: 1, original_filename: original_filename)
  end

  context 'uploading to s3' do
    before(:each) do
      setup_s3
    end

    describe "#store_upload" do
      let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
      let(:s3_helper) { S3Helper.new(SiteSetting.s3_upload_bucket, '', client: s3_client) }
      let(:store) { FileStore::S3Store.new(s3_helper) }
      let(:upload_opts) do
        {
          acl: "public-read",
          cache_control: "max-age=31556952, public, immutable",
          content_type: "image/png"
        }
      end

      it "does not provide a content_disposition for images" do
        s3_helper.expects(:upload).with(uploaded_file, kind_of(String), upload_opts).returns(["path", "etag"])
        upload = build_upload
        store.store_upload(uploaded_file, upload)
      end

      context "when the file is a PDF" do
        let(:original_filename) { "small.pdf" }
        let(:uploaded_file) { file_from_fixtures("small.pdf", "pdf") }

        it "adds an attachment content-disposition with the original filename" do
          disp_opts = { content_disposition: "attachment; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}", content_type: "application/pdf" }
          s3_helper.expects(:upload).with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts)).returns(["path", "etag"])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      context "when the file is a video" do
        let(:original_filename) { "small.mp4" }
        let(:uploaded_file) { file_from_fixtures("small.mp4", "media") }

        it "adds an attachment content-disposition with the original filename" do
          disp_opts = { content_disposition: "attachment; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}", content_type: "application/mp4" }
          s3_helper.expects(:upload).with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts)).returns(["path", "etag"])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      context "when the file is audio" do
        let(:original_filename) { "small.mp3" }
        let(:uploaded_file) { file_from_fixtures("small.mp3", "media") }

        it "adds an attachment content-disposition with the original filename" do
          disp_opts = { content_disposition: "attachment; filename=\"#{original_filename}\"; filename*=UTF-8''#{original_filename}", content_type: "audio/mpeg" }
          s3_helper.expects(:upload).with(uploaded_file, kind_of(String), upload_opts.merge(disp_opts)).returns(["path", "etag"])
          upload = build_upload
          store.store_upload(uploaded_file, upload)
        end
      end

      it "returns the correct url for default and second multisite db" do
        test_multisite_connection('default') do
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
          expect(upload.etag).to eq("ETag")
        end

        test_multisite_connection('second') do
          upload_path = Discourse.store.upload_path
          upload = build_upload
          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//#{SiteSetting.s3_upload_bucket}.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/c530c06cf89c410c0355d7852644a73fc3ec8c04.png"
          )
          expect(upload.etag).to eq("ETag")
        end
      end
    end
  end

  context 'removal from s3' do
    before do
      setup_s3
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
    let(:s3_helper) { store.s3_helper }
    let(:s3_object) { stub }

    before(:each) do
      setup_s3
      SiteSetting.s3_upload_bucket = "some-really-cool-bucket"
      SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
    end

    before do
      s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "etag"))
    end

    describe "when secure attachments are enabled" do
      it "returns signed URL with correct path" do
        test_multisite_connection('default') do
          upload = Fabricate(:upload, original_filename: "small.pdf", extension: "pdf", secure: true)

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("#{upload_path}/original/1X/#{upload.sha1}.pdf").returns(s3_object).at_least_once
          s3_object.expects(:presigned_url).with(:get, expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS)

          upload.url = store.store_upload(uploaded_file, upload)
          expect(upload.url).to eq(
            "//some-really-cool-bucket.s3.dualstack.us-west-1.amazonaws.com/#{upload_path}/original/1X/#{upload.sha1}.pdf"
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

  describe "#has_been_uploaded?" do
    before do
      setup_s3
      SiteSetting.s3_upload_bucket = "s3-upload-bucket/test"
    end

    let(:store) { FileStore::S3Store.new }

    it "returns false for blank urls and bad urls" do
      expect(store.has_been_uploaded?("")).to eq(false)
      expect(store.has_been_uploaded?("http://test@test.com:test/test.git")).to eq(false)
      expect(store.has_been_uploaded?("http:///+test@test.com/test.git")).to eq(false)
    end

    it "returns true if the base hostname is the same for both urls" do
      url = "https://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(true)
    end

    it "returns false if the base hostname is the same for both urls BUT the bucket name is different in the path" do
      bucket = "someotherbucket"
      url = "https://s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{bucket}/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(false)
    end

    it "returns false if the hostnames do not match and the s3_cdn_url is blank" do
      url = "https://www.someotherhostname.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(false)
    end

    it "returns true if the s3_cdn_url is present and matches the url hostname" do
      SiteSetting.s3_cdn_url = "https://www.someotherhostname.com"
      url = "https://www.someotherhostname.com/test/original/2X/d/dd7964f5fd13e1103c5244ca30abe1936c0a4b88.png"
      expect(store.has_been_uploaded?(url)).to eq(true)
    end

    it "returns false if the URI is an invalid mailto link" do
      link = 'mailto: roman;@test.com'

      expect(store.has_been_uploaded?(link)).to eq(false)
    end
  end
end
