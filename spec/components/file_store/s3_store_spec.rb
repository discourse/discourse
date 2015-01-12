require 'spec_helper'
require 'file_store/s3_store'

describe FileStore::S3Store do

  let(:s3_helper) { stub }
  let(:store) { FileStore::S3Store.new(s3_helper) }

  let(:upload) { build(:upload) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  let(:optimized_image) { build(:optimized_image) }
  let(:optimized_image_file) { file_from_fixtures("logo.png") }

  let(:avatar) { build(:upload) }

  before(:each) do
    SiteSetting.stubs(:s3_upload_bucket).returns("S3_Upload_Bucket")
    SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
    SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
  end

  describe ".store_upload" do

    it "returns an absolute schemaless url" do
      upload.stubs(:id).returns(42)
      upload.stubs(:extension).returns(".png")
      s3_helper.expects(:upload)
      expect(store.store_upload(uploaded_file, upload)).to eq("//s3_upload_bucket.s3.amazonaws.com/42e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98.png")
    end

  end

  describe ".store_optimized_image" do

    it "returns an absolute schemaless url" do
      optimized_image.stubs(:id).returns(42)
      s3_helper.expects(:upload)
      expect(store.store_optimized_image(optimized_image_file, optimized_image)).to eq("//s3_upload_bucket.s3.amazonaws.com/4286f7e437faa5a7fce15d1ddcb9eaeaea377667b8_100x200.png")
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
      expect(store.has_been_uploaded?("//s3.amazonaws.com/s3_upload_bucket/1337.png")).to eq(false)
      expect(store.has_been_uploaded?("//s4_upload_bucket.s3.amazonaws.com/1337.png")).to eq(false)
    end

  end

  describe ".absolute_base_url" do

    it "returns a lowercase schemaless absolute url" do
      expect(store.absolute_base_url).to eq("//s3_upload_bucket.s3.amazonaws.com")
    end

  end

  it "is external" do
    expect(store.external?).to eq(true)
    expect(store.internal?).to eq(false)
  end

  describe ".download" do

    it "does nothing if the file hasn't been uploaded to that store" do
      upload.stubs(:url).returns("/path/to/image.png")
      FileHelper.expects(:download).never
      store.download(upload)
    end

    it "works" do
      upload.stubs(:url).returns("//s3_upload_bucket.s3.amazonaws.com/1337.png")
      max_file_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
      FileHelper.expects(:download).with("http://s3_upload_bucket.s3.amazonaws.com/1337.png", max_file_size, "discourse-s3", true)
      store.download(upload)
    end

  end

  describe ".avatar_template" do

    it "is present" do
      expect(store.avatar_template(avatar)).to eq("//s3_upload_bucket.s3.amazonaws.com/avatars/e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98/{size}.png")
    end

  end

  describe ".purge_tombstone" do

    it "updates tombstone lifecycle" do
      s3_helper.expects(:update_tombstone_lifecycle)
      store.purge_tombstone(1.day)
    end

  end

end
