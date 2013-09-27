require 'spec_helper'
require 'digest/sha1'

describe Upload do

  it { should belong_to :user }

  it { should have_many :post_uploads }
  it { should have_many :posts }

  it { should have_many :optimized_images }

  it { should validate_presence_of :original_filename }
  it { should validate_presence_of :filesize }

  let(:upload) { build(:upload) }
  let(:thumbnail) { build(:optimized_image, upload: upload) }

  let(:user_id) { 1 }
  let(:url) { "http://domain.com" }

  let(:image) do
    ActionDispatch::Http::UploadedFile.new({
      filename: 'logo.png',
      tempfile: File.new("#{Rails.root}/spec/fixtures/images/logo.png")
    })
  end

  let(:image_sha1) { Digest::SHA1.file(image.tempfile).hexdigest }
  let(:image_filesize) { File.size(image.tempfile) }

  let(:attachment) do
    ActionDispatch::Http::UploadedFile.new({
      filename: File.basename(__FILE__),
      tempfile: File.new(__FILE__)
    })
  end

  let(:attachment_filesize) { File.size(attachment.tempfile) }

  context ".create_thumbnail!" do

    it "does not create a thumbnail when disabled" do
      SiteSetting.stubs(:create_thumbnails?).returns(false)
      OptimizedImage.expects(:create_for).never
      upload.create_thumbnail!(100, 100)
    end

    it "does not create another thumbnail" do
      SiteSetting.expects(:create_thumbnails?).returns(true)
      upload.expects(:has_thumbnail?).returns(true)
      OptimizedImage.expects(:create_for).never
      upload.create_thumbnail!(100, 100)
    end

    it "creates a thumbnail" do
      upload = Fabricate(:upload)
      thumbnail = Fabricate(:optimized_image, upload: upload)
      SiteSetting.expects(:create_thumbnails?).returns(true)
      upload.expects(:has_thumbnail?).returns(false)
      OptimizedImage.expects(:create_for).returns(thumbnail)
      upload.create_thumbnail!(100, 100)
      upload.reload
      upload.optimized_images.count.should == 1
    end

  end

  context ".create_for" do

    it "does not create another upload if it already exists" do
      Upload.expects(:where).with(sha1: image_sha1).returns([upload])
      Upload.expects(:create!).never
      Upload.create_for(user_id, image, image_filesize).should == upload
    end

    it "computes width & height for images" do
      SiteSetting.expects(:authorized_image?).returns(true)
      FastImage.any_instance.expects(:size).returns([100, 200])
      ImageSizer.expects(:resize)
      ActionDispatch::Http::UploadedFile.any_instance.expects(:rewind)
      Upload.create_for(user_id, image, image_filesize)
    end

    it "does not create an upload when there is an error with FastImage" do
      SiteSetting.expects(:authorized_image?).returns(true)
      Upload.expects(:create!).never
      expect { Upload.create_for(user_id, attachment, attachment_filesize) }.to raise_error(FastImage::UnknownImageType)
    end

    it "does not compute width & height for non-image" do
      SiteSetting.expects(:authorized_image?).returns(false)
      FastImage.any_instance.expects(:size).never
      Upload.create_for(user_id, image, image_filesize)
    end

    it "saves proper information" do
      store = {}
      Discourse.expects(:store).returns(store)
      store.expects(:store_upload).returns(url)
      upload = Upload.create_for(user_id, image, image_filesize)
      upload.user_id.should == user_id
      upload.original_filename.should == image.original_filename
      upload.filesize.should == File.size(image.tempfile)
      upload.sha1.should == Digest::SHA1.file(image.tempfile).hexdigest
      upload.width.should == 244
      upload.height.should == 66
      upload.url.should == url
    end

  end

  context ".get_from_url" do

    it "works when the file has been uploaded" do
      Upload.expects(:where).returns([]).once
      Upload.get_from_url("/uploads/default/1/10387531.jpg")
    end

    it "works when using a cdn" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      Upload.expects(:where).with(url: "/uploads/default/1/02395732905.jpg").returns([]).once
      Upload.get_from_url("http://my.cdn.com/uploads/default/1/02395732905.jpg")
    end

    it "works only when the file has been uploaded" do
      Upload.expects(:where).never
      Upload.get_from_url("http://domain.com/my/file.txt")
    end

  end

end
