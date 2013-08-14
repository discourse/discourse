require 'spec_helper'
require 'file_store/local_store'

describe LocalStore do

  let(:store) { LocalStore.new }

  let(:upload) { build(:upload) }
  let(:uploaded_file) do
    ActionDispatch::Http::UploadedFile.new({
      filename: 'logo.png',
      tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
    })
  end

  let(:optimized_image) { build(:optimized_image) }

  it "is internal" do
    store.internal?.should == true
    store.external?.should == false
  end

  describe "store_upload" do

    it "returns a relative url" do
      Time.stubs(:now).returns(Time.utc(2013, 2, 17, 12, 0, 0, 0))
      upload.stubs(:id).returns(42)
      store.expects(:copy_file)
      store.store_upload(uploaded_file, upload).should == "/uploads/default/42/253dc8edf9d4ada1.png"
    end

  end

  describe "store_optimized_image" do

    it "returns a relative url" do
      store.expects(:copy_file)
      store.store_optimized_image({}, optimized_image).should == "/uploads/default/_optimized/86f/7e4/37faa5a7fc_100x200.png"
    end

  end

  describe "remove_upload" do

    it "does not delete non uploaded" do
      File.expects(:delete).never
      upload = Upload.new
      upload.stubs(:url).returns("/path/to/file")
      store.remove_upload(upload)
    end

    it "deletes the file locally" do
      File.expects(:delete)
      upload = Upload.new
      upload.stubs(:url).returns("/uploads/default/42/253dc8edf9d4ada1.png")
      store.remove_upload(upload)
    end

  end

  describe "remove_optimized_image" do

  end

  describe "remove_avatar" do

  end


  describe "has_been_uploaded?" do

    it "identifies local or relatives urls" do
      Discourse.expects(:base_url_no_prefix).returns("http://discuss.site.com")
      store.has_been_uploaded?("http://discuss.site.com/uploads/default/42/0123456789ABCDEF.jpg").should == true
      store.has_been_uploaded?("/uploads/default/42/0123456789ABCDEF.jpg").should == true
    end

    it "identifies local urls when using a CDN" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      store.has_been_uploaded?("http://my.cdn.com/uploads/default/42/0123456789ABCDEF.jpg").should == true
    end

    it "does not match dummy urls" do
      store.has_been_uploaded?("http://domain.com/uploads/default/42/0123456789ABCDEF.jpg").should == false
    end

  end

end
