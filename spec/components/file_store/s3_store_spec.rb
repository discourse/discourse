require 'spec_helper'
require 'fog'
require 'file_store/s3_store'

describe S3Store do

  let(:store) { S3Store.new }

  let(:upload) { build(:upload) }
  let(:uploaded_file) do
    ActionDispatch::Http::UploadedFile.new({
      filename: 'logo.png',
      tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
    })
  end

  let(:optimized_image) { build(:optimized_image) }
  let(:optimized_image_file) do
    ActionDispatch::Http::UploadedFile.new({
      filename: 'logo.png',
      tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
    })
  end

  before(:each) do
    SiteSetting.stubs(:s3_upload_bucket).returns("S3_Upload_Bucket")
    SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
    SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
    Fog.mock!
  end

  after(:each) { Fog.unmock! }

  it "is internal" do
    store.external?.should == true
    store.internal?.should == false
  end

  describe "store_upload" do

    it "returns a relative url" do
      upload.stubs(:id).returns(42)
      upload.stubs(:extension).returns(".png")
      store.store_upload(uploaded_file, upload).should == "//s3_upload_bucket.s3.amazonaws.com/42e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98.png"
    end

  end

  describe "store_optimized_image" do

    it "returns a relative url" do
      optimized_image.stubs(:id).returns(42)
      store.store_optimized_image(optimized_image_file, optimized_image).should == "//s3_upload_bucket.s3.amazonaws.com/4286f7e437faa5a7fce15d1ddcb9eaeaea377667b8_100x200.png"
    end

  end

  describe "remove_upload" do

    it "does not delete non uploaded file" do
      store.expects(:remove).never
      upload = Upload.new
      upload.stubs(:url).returns("//other_bucket.s3.amazonaws.com/42.png")
      store.remove_upload(upload)
    end

    it "deletes the file on s3" do
      store.expects(:remove)
      upload = Upload.new
      upload.stubs(:url).returns("//s3_upload_bucket.s3.amazonaws.com/42.png")
      store.remove_upload(upload)
    end

  end

  describe "remove_optimized_image" do

  end

  describe "remove_avatar" do

  end

  describe "has_been_uploaded?" do

    it "identifies S3 uploads" do
      SiteSetting.stubs(:enable_s3_uploads).returns(true)
      store.has_been_uploaded?("//s3_upload_bucket.s3.amazonaws.com/1337.png").should == true
    end

    it "does not match other s3 urls" do
      store.has_been_uploaded?("//s3.amazonaws.com/Bucket/1337.png").should == false
    end

  end

end
