require 'spec_helper'
require 'fog'
require 'file_store/s3_store'

describe FileStore::S3Store do

  let(:store) { FileStore::S3Store.new }

  let(:upload) { build(:upload) }
  let(:uploaded_file) { File.new("#{Rails.root}/spec/fixtures/images/logo.png") }

  let(:optimized_image) { build(:optimized_image) }
  let(:optimized_image_file) { File.new("#{Rails.root}/spec/fixtures/images/logo.png") }

  let(:avatar) { build(:upload) }
  let(:avatar_file) { File.new("#{Rails.root}/spec/fixtures/images/logo-dev.png") }

  before(:each) do
    SiteSetting.stubs(:s3_upload_bucket).returns("S3_Upload_Bucket")
    SiteSetting.stubs(:s3_access_key_id).returns("s3_access_key_id")
    SiteSetting.stubs(:s3_secret_access_key).returns("s3_secret_access_key")
    Fog.mock!
    Fog::Mock.reset
    Fog::Mock.delay = 0
  end

  after(:each) { Fog.unmock! }

  describe ".store_upload" do

    it "returns an absolute schemaless url" do
      upload.stubs(:id).returns(42)
      upload.stubs(:extension).returns(".png")
      store.store_upload(uploaded_file, upload).should == "//s3_upload_bucket.s3.amazonaws.com/42e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98.png"
    end

  end

  describe ".store_optimized_image" do

    it "returns an absolute schemaless url" do
      optimized_image.stubs(:id).returns(42)
      store.store_optimized_image(optimized_image_file, optimized_image).should == "//s3_upload_bucket.s3.amazonaws.com/4286f7e437faa5a7fce15d1ddcb9eaeaea377667b8_100x200.png"
    end

  end

  describe ".store_avatar" do

    it "returns an absolute schemaless url" do
      avatar.stubs(:id).returns(42)
      store.store_avatar(avatar_file, avatar, 100).should == "//s3_upload_bucket.s3.amazonaws.com/avatars/e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98/100.png"
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
      store.has_been_uploaded?("//s3_upload_bucket.s3.amazonaws.com/1337.png").should == true
    end

    it "does not match other s3 urls" do
      store.has_been_uploaded?("//s3.amazonaws.com/s3_upload_bucket/1337.png").should == false
      store.has_been_uploaded?("//s4_upload_bucket.s3.amazonaws.com/1337.png").should == false
    end

  end

  describe ".absolute_base_url" do

    it "returns a lowercase schemaless absolute url" do
      store.absolute_base_url.should == "//s3_upload_bucket.s3.amazonaws.com"
    end

  end

  it "is external" do
    store.external?.should == true
    store.internal?.should == false
  end

  describe ".avatar_template" do

    it "is present" do
      store.avatar_template(avatar).should == "//s3_upload_bucket.s3.amazonaws.com/avatars/e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98/{size}.png"
    end

  end

end
