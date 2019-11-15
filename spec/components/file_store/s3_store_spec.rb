# frozen_string_literal: true

require 'rails_helper'
require 'file_store/s3_store'
require 'file_store/local_store'

describe FileStore::S3Store do

  let(:store) { FileStore::S3Store.new }
  let(:s3_helper) { store.instance_variable_get(:@s3_helper) }
  fab!(:upload) { Fabricate(:upload) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  fab!(:optimized_image) { Fabricate(:optimized_image) }
  let(:optimized_image_file) { file_from_fixtures("logo.png") }

  before(:each) do
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"
    SiteSetting.s3_access_key_id = "s3-access-key-id"
    SiteSetting.s3_secret_access_key = "s3-secret-access-key"
    SiteSetting.enable_s3_uploads = true
  end

  shared_context 's3 helpers' do
    fab!(:upload) do
      Fabricate(:upload, sha1: Digest::SHA1.hexdigest('secreet image string'))
    end

    let(:store) { FileStore::S3Store.new }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:resource) { Aws::S3::Resource.new(client: client) }
    let(:s3_bucket) { resource.bucket("s3-upload-bucket") }
    let(:s3_helper) { store.instance_variable_get(:@s3_helper) }

    before do
      SiteSetting.s3_region = 'us-west-1'
    end
  end

  context 'uploading to s3' do
    include_context "s3 helpers"

    let(:s3_object) { stub }
    let(:etag) { "etag" }

    before do
      s3_object.stubs(:put).returns(Aws::S3::Types::PutObjectOutput.new(etag: "\"#{etag}\""))
    end

    describe "#store_upload" do
      it "returns an absolute schemaless url" do
        store.expects(:get_depth_for).with(upload.id).returns(0)
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once

        s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)

        expect(store.store_upload(uploaded_file, upload)).to eq(
          "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.png"
        )
        expect(upload.etag).to eq(etag)
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "returns an absolute schemaless url" do
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket)

          s3_bucket.expects(:object).with("discourse-uploads/original/1X/#{upload.sha1}.png").returns(s3_object)

          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/discourse-uploads/original/1X/#{upload.sha1}.png"
          )
          expect(upload.etag).to eq(etag)
        end
      end

      describe "when private uploads are enabled" do
        it "returns signed URL for eligible private upload" do
          SiteSetting.prevent_anons_from_downloading_files = true
          SiteSetting.authorized_extensions = "pdf|png|jpg|gif"
          upload.update!(original_filename: "small.pdf", extension: "pdf")

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.pdf").returns(s3_object).at_least_once
          s3_object.expects(:presigned_url).with(:get, expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS)

          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.pdf"
          )

          expect(store.url_for(upload)).not_to eq(upload.url)
        end

        it "returns regular URL for ineligible private upload" do
          SiteSetting.prevent_anons_from_downloading_files = true

          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object).at_least_once

          expect(store.store_upload(uploaded_file, upload)).to eq(
            "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.png"
          )

          expect(store.url_for(upload)).to eq(upload.url)
        end
      end
    end

    describe "#store_optimized_image" do
      it "returns an absolute schemaless url" do
        store.expects(:get_depth_for).with(optimized_image.upload.id).returns(0)
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        path = "optimized/1X/#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200.png"

        s3_bucket.expects(:object).with(path).returns(s3_object)

        expect(store.store_optimized_image(optimized_image_file, optimized_image)).to eq(
          "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{path}"
        )
        expect(optimized_image.etag).to eq(etag)
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "returns an absolute schemaless url" do
          store.expects(:get_depth_for).with(optimized_image.upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket)
          path = "discourse-uploads/optimized/1X/#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200.png"

          s3_bucket.expects(:object).with(path).returns(s3_object)

          expect(store.store_optimized_image(optimized_image_file, optimized_image)).to eq(
            "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{path}"
          )
          expect(optimized_image.etag).to eq(etag)
        end
      end
    end
  end

  context 'copying files in S3' do
    include_context "s3 helpers"

    describe '#copy_file' do
      it "copies the from in S3 with the right paths" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket)

        upload.update!(
          url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.png"
        )

        source = Discourse.store.get_path_for_upload(upload)
        destination = Discourse.store.get_path_for_upload(upload).sub('.png', '.jpg')

        s3_object = stub

        s3_bucket.expects(:object).with(destination).returns(s3_object)

        s3_object.expects(:copy_from).with(
          copy_source: "s3-upload-bucket/#{source}"
        )

        store.copy_file(upload.url, source, destination)
      end
    end
  end

  context 'removal from s3' do
    include_context "s3 helpers"

    describe "#remove_upload" do
      it "removes the file from s3 with the right paths" do
        store.expects(:get_depth_for).with(upload.id).returns(0)
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/original/1X/#{upload.sha1}.png")
        s3_object = stub

        s3_bucket.expects(:object).with("tombstone/original/1X/#{upload.sha1}.png").returns(s3_object)
        s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/original/1X/#{upload.sha1}.png")
        s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)
        s3_object.expects(:delete)

        store.remove_upload(upload)
      end

      it "removes the optimized image from s3 with the right paths" do
        optimized = Fabricate(:optimized_image, version: 1)
        upload = optimized.upload
        path = "optimized/1X/#{upload.sha1}_#{optimized.version}_#{optimized.width}x#{optimized.height}.png"

        store.expects(:get_depth_for).with(upload.id).returns(0)
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        optimized.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/#{path}")
        s3_object = stub

        s3_bucket.expects(:object).with("tombstone/#{path}").returns(s3_object)
        s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/#{path}")
        s3_bucket.expects(:object).with(path).returns(s3_object)
        s3_object.expects(:delete)

        store.remove_optimized_image(optimized)
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "removes the file from s3 with the right paths" do
          store.expects(:get_depth_for).with(upload.id).returns(0)
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          upload.update!(url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com/discourse-uploads/original/1X/#{upload.sha1}.png")
          s3_object = stub

          s3_bucket.expects(:object).with("discourse-uploads/tombstone/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/discourse-uploads/original/1X/#{upload.sha1}.png")
          s3_bucket.expects(:object).with("discourse-uploads/original/1X/#{upload.sha1}.png").returns(s3_object)
          s3_object.expects(:delete)

          store.remove_upload(upload)
        end
      end
    end

    describe "#remove_optimized_image" do
      fab!(:optimized_image) { Fabricate(:optimized_image, upload: upload) }

      let(:image_path) do
        FileStore::BaseStore.new.get_path_for_optimized_image(optimized_image)
      end

      before do
        optimized_image.update!(
          url: "//s3-upload-bucket.s3.dualstack.us-west-1.amazonaws.com#{image_path}"
        )
      end

      it "removes the file from s3 with the right paths" do
        s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
        s3_object = stub

        s3_bucket.expects(:object).with("tombstone/#{image_path}").returns(s3_object)
        s3_object.expects(:copy_from).with(copy_source: "s3-upload-bucket/#{image_path}")
        s3_bucket.expects(:object).with("#{image_path}").returns(s3_object)
        s3_object.expects(:delete)

        store.remove_optimized_image(optimized_image)
      end

      describe "when s3_upload_bucket includes folders path" do
        before do
          SiteSetting.s3_upload_bucket = "s3-upload-bucket/discourse-uploads"
        end

        it "removes the file from s3 with the right paths" do
          s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
          s3_object = stub

          s3_bucket.expects(:object)
            .with("discourse-uploads/tombstone/#{image_path}")
            .returns(s3_object)

          s3_object.expects(:copy_from).with(
            copy_source: "s3-upload-bucket/discourse-uploads/#{image_path}"
          )

          s3_bucket.expects(:object).with(
            "discourse-uploads/#{image_path}"
          ).returns(s3_object)

          s3_object.expects(:delete)

          store.remove_optimized_image(optimized_image)
        end
      end
    end
  end

  describe ".has_been_uploaded?" do

    it "identifies S3 uploads" do
      expect(store.has_been_uploaded?("//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/1337.png")).to eq(true)
    end

    it "does not match other s3 urls" do
      expect(store.has_been_uploaded?("//s3-upload-bucket.s3.amazonaws.com/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s3-upload-bucket.s3-us-east-1.amazonaws.com/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s3.amazonaws.com/s3-upload-bucket/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s4_upload_bucket.s3.amazonaws.com/1337.png")).to eq(false)
    end

  end

  describe ".absolute_base_url" do
    it "returns a lowercase schemaless absolute url" do
      expect(store.absolute_base_url).to eq("//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com")
    end

    it "uses the proper endpoint" do
      SiteSetting.s3_region = "us-east-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com")

      SiteSetting.s3_region = "us-west-2"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3-upload-bucket.s3.dualstack.us-west-2.amazonaws.com")

      SiteSetting.s3_region = "cn-north-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3-upload-bucket.s3.cn-north-1.amazonaws.com.cn")

      SiteSetting.s3_region = "cn-northwest-1"
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3-upload-bucket.s3.cn-northwest-1.amazonaws.com.cn")
    end

  end

  it "is external" do
    expect(store.external?).to eq(true)
    expect(store.internal?).to eq(false)
  end

  describe ".purge_tombstone" do

    it "updates tombstone lifecycle" do
      s3_helper.expects(:update_tombstone_lifecycle)
      store.purge_tombstone(1.day)
    end

  end

  describe ".path_for" do
    def assert_path(path, expected)
      upload = Upload.new(url: path)

      path = store.path_for(upload)
      expected = FileStore::LocalStore.new.path_for(upload) if expected

      expect(path).to eq(expected)
    end

    it "correctly falls back to local" do
      assert_path("/hello", "/hello")
      assert_path("//hello", nil)
      assert_path("http://hello", nil)
      assert_path("https://hello", nil)
    end
  end

  context 'update ACL' do
    include_context "s3 helpers"
    let(:s3_object) { stub }

    describe ".update_upload_ACL" do
      it "sets acl to private when private uploads are enabled" do
        SiteSetting.prevent_anons_from_downloading_files = true
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)
        s3_object.expects(:acl).returns(s3_object)
        s3_object.expects(:put).with(acl: "private").returns(s3_object)

        expect(store.update_upload_ACL(upload)).to be_truthy
      end

      it "sets acl to public when private uploads are disabled" do
        SiteSetting.prevent_anons_from_downloading_files = false
        s3_helper.expects(:s3_bucket).returns(s3_bucket)
        s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)
        s3_object.expects(:acl).returns(s3_object)
        s3_object.expects(:put).with(acl: "public-read").returns(s3_object)

        expect(store.update_upload_ACL(upload)).to be_truthy
      end
    end
  end

  describe '.cdn_url' do

    it 'supports subfolder' do
      SiteSetting.s3_upload_bucket = 's3-upload-bucket/livechat'
      SiteSetting.s3_cdn_url = 'https://rainbow.com'

      # none of this should matter at all
      # subfolder should not leak into uploads
      global_setting :relative_url_root, '/community'
      Discourse.stubs(:base_uri).returns("/community")

      url = "//s3-upload-bucket.s3.dualstack.us-east-1.amazonaws.com/livechat/original/gif.png"

      expect(store.cdn_url(url)).to eq("https://rainbow.com/original/gif.png")
    end
  end

  describe ".download_url" do
    include_context "s3 helpers"
    let(:s3_object) { stub }

    it "returns correct short URL with dl=1 param" do
      expect(store.download_url(upload)).to eq("#{upload.short_path}?dl=1")
    end
  end

  describe ".url_for" do
    include_context "s3 helpers"
    let(:s3_object) { stub }

    it "returns signed URL with content disposition when requesting to download image" do
      s3_helper.expects(:s3_bucket).returns(s3_bucket).at_least_once
      s3_bucket.expects(:object).with("original/1X/#{upload.sha1}.png").returns(s3_object)
      opts = {
        expires_in: S3Helper::DOWNLOAD_URL_EXPIRES_AFTER_SECONDS,
        response_content_disposition: %Q|attachment; filename="#{upload.original_filename}"; filename*=UTF-8''#{upload.original_filename}|
      }

      s3_object.expects(:presigned_url).with(:get, opts)

      expect(store.url_for(upload, force_download: true)).not_to eq(upload.url)
    end
  end

end
