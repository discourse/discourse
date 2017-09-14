require 'rails_helper'
require 'file_store/local_store'

describe FileStore::LocalStore do

  let(:store) { FileStore::LocalStore.new }

  let(:upload) { Fabricate(:upload) }
  let(:uploaded_file) { file_from_fixtures("logo.png") }

  let(:optimized_image) { Fabricate(:optimized_image) }

  describe ".store_upload" do

    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_upload(uploaded_file, upload)).to match(/\/uploads\/default\/original\/.+#{upload.sha1}\.png/)
    end

  end

  describe ".store_optimized_image" do

    it "returns a relative url" do
      store.expects(:copy_file)
      expect(store.store_optimized_image({}, optimized_image)).to match(/\/uploads\/default\/optimized\/.+#{optimized_image.upload.sha1}_#{OptimizedImage::VERSION}_100x200\.png/)
    end

  end

  describe ".remove_upload" do

    it "does not delete non uploaded" do
      FileUtils.expects(:mkdir_p).never
      store.remove_upload(upload)
    end

    it "moves the file to the tombstone" do
      filename = File.basename(store.path_for(upload))
      store.remove_upload(upload)
      expect(File.exist?(store.tombstone_dir + "/" + filename))
    end

  end

  describe ".remove_optimized_image" do
    let(:optimized_image) { Fabricate(:optimized_image, url: "/uploads/default/_optimized/42/253dc8edf9d4ada1.png") }

    it "moves the file to the tombstone" do
      FileUtils.expects(:mkdir_p)
      FileUtils.expects(:move)
      File.expects(:exists?).returns(true)
      store.remove_optimized_image(optimized_image)
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

  def stub_for_subfolder
    GlobalSetting.stubs(:relative_url_root).returns('/forum')
    Discourse.stubs(:base_uri).returns("/forum")
  end

  describe ".absolute_base_url" do

    it "is present" do
      expect(store.absolute_base_url).to eq("http://test.localhost/uploads/default")
    end

    it "supports subfolder" do
      stub_for_subfolder
      expect(store.absolute_base_url).to eq("http://test.localhost/forum/uploads/default")
    end

  end

  describe ".relative_base_url" do

    it "is present" do
      expect(store.relative_base_url).to eq("/uploads/default")
    end

    it "supports subfolder" do
      stub_for_subfolder
      expect(store.relative_base_url).to eq("/forum/uploads/default")
    end

  end

  it "is internal" do
    expect(store.internal?).to eq(true)
    expect(store.external?).to eq(false)
  end

end
