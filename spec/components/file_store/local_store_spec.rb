require 'spec_helper'
require 'file_store/local_store'

describe FileStore::LocalStore do

  let(:store) { FileStore::LocalStore.new }

  let(:upload) { Fabricate(:upload) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  let(:optimized_image) { Fabricate(:optimized_image) }

  describe ".store_upload" do

    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_upload(uploaded_file, upload)).to match(/\/uploads\/default\/original\/.+e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98\.png/)
    end

  end

  describe ".store_optimized_image" do

    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_optimized_image({}, optimized_image)).to match(/\/uploads\/default\/optimized\/.+e9d71f5ee7c92d6dc9e92ffdad17b8bd49418f98_#{OptimizedImage::VERSION}_100x200\.png/)
    end

  end

  describe ".remove_upload" do

    it "does not delete non uploaded" do
      FileUtils.expects(:mkdir_p).never
      upload = Upload.new
      upload.stubs(:url).returns("/path/to/file")
      store.remove_upload(upload)
    end

    it "moves the file to the tombstone" do
      FileUtils.expects(:mkdir_p)
      FileUtils.expects(:move)
      upload = Upload.new
      upload.stubs(:url).returns("/uploads/default/42/253dc8edf9d4ada1.png")
      store.remove_upload(upload)
    end

  end

  describe ".remove_optimized_image" do

    it "moves the file to the tombstone" do
      FileUtils.expects(:mkdir_p)
      FileUtils.expects(:move)
      oi = OptimizedImage.new
      oi.stubs(:url).returns("/uploads/default/_optimized/42/253dc8edf9d4ada1.png")
      store.remove_optimized_image(upload)
    end

  end

  describe ".has_been_uploaded?" do

    it "identifies relatives urls" do
      expect(store.has_been_uploaded?("/uploads/default/42/0123456789ABCDEF.jpg")).to eq(true)
    end

    it "identifies local urls" do
      Discourse.stubs(:base_url_no_prefix).returns("http://discuss.site.com")
      expect(store.has_been_uploaded?("http://discuss.site.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(true)
      expect(store.has_been_uploaded?("//discuss.site.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(true)
    end

    it "identifies local urls when using a CDN" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      expect(store.has_been_uploaded?("http://my.cdn.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(true)
      expect(store.has_been_uploaded?("//my.cdn.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(true)
    end

    it "does not match dummy urls" do
      expect(store.has_been_uploaded?("http://domain.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(false)
      expect(store.has_been_uploaded?("//domain.com/uploads/default/42/0123456789ABCDEF.jpg")).to eq(false)
    end

  end

  describe ".absolute_base_url" do

    it "is present" do
      expect(store.absolute_base_url).to eq("http://test.localhost/uploads/default")
    end

  end

  describe ".relative_base_url" do

    it "is present" do
      expect(store.relative_base_url).to eq("/uploads/default")
    end

  end

  it "is internal" do
    expect(store.internal?).to eq(true)
    expect(store.external?).to eq(false)
  end

end
