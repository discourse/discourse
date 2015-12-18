require 'rails_helper'
require 'file_store/s3_store'
require 'file_store/local_store'

describe FileStore::S3Store do

  let(:s3_helper) { stub }
  let(:store) { FileStore::S3Store.new(s3_helper) }

  let(:upload) { Fabricate(:upload) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  let(:optimized_image) { Fabricate(:optimized_image) }
  let(:optimized_image_file) { file_from_fixtures("logo.png") }

  before(:each) do
    SiteSetting.stubs(:s3_upload_bucket).returns("S3_Upload_Bucket")
    SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
    SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
  end

  describe ".store_upload" do

    it "returns an absolute schemaless url" do
      s3_helper.expects(:upload)
      expect(store.store_upload(uploaded_file, upload)).to match(/\/\/s3_upload_bucket\.s3\.amazonaws\.com\/original\/.+e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98\.png/)
    end

  end

  describe ".store_optimized_image" do

    it "returns an absolute schemaless url" do
      s3_helper.expects(:upload)
      expect(store.store_optimized_image(optimized_image_file, optimized_image)).to match(/\/\/s3_upload_bucket\.s3\.amazonaws\.com\/optimized\/.+e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98_#{OptimizedImage::VERSION}_100x200\.png/)
    end

  end

  describe ".remove_upload" do

    it "calls remove_file with the url" do
      store.expects(:remove_file).with(upload.url)
      store.remove_upload(upload)
    end

  end

  describe ".remove_optimized_image" do

    it "calls remove_file with the url" do
      store.expects(:remove_file).with(optimized_image.url)
      store.remove_optimized_image(optimized_image)
    end

  end

  describe ".has_been_uploaded?" do

    it "identifies S3 uploads" do
      expect(store.has_been_uploaded?("//s3_upload_bucket.s3.amazonaws.com/1337.png")).to eq(true)
    end

    it "does not match other s3 urls" do
      expect(store.has_been_uploaded?("//s3_upload_bucket.s3-us-east-1.amazonaws.com/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s3.amazonaws.com/s3_upload_bucket/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s4_upload_bucket.s3.amazonaws.com/1337.png")).to eq(false)
    end

  end

  describe ".absolute_base_url" do

    it "returns a lowercase schemaless absolute url" do
      expect(store.absolute_base_url).to eq("//s3_upload_bucket.s3.amazonaws.com")
    end

    it "uses the proper endpoint" do
      SiteSetting.stubs(:s3_region).returns("us-east-1")
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3_upload_bucket.s3.amazonaws.com")

      SiteSetting.stubs(:s3_region).returns("us-east-2")
      expect(FileStore::S3Store.new(s3_helper).absolute_base_url).to eq("//s3_upload_bucket.s3-us-east-2.amazonaws.com")
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

end
