require 'spec_helper'
require 'digest/sha1'

describe Upload do
  it { should belong_to :user }

  it { should have_many :post_uploads }
  it { should have_many :posts }

  it { should have_many :optimized_images }

  let(:upload) { build(:upload) }
  let(:thumbnail) { build(:optimized_image, upload: upload) }

  let(:user_id) { 1 }
  let(:url) { "http://domain.com" }

  let(:image_path) { "#{Rails.root}/spec/fixtures/images/logo.png" }
  let(:image) { File.new(image_path) }
  let(:image_filename) { File.basename(image_path) }
  let(:image_filesize) { File.size(image_path) }
  let(:image_sha1) { Digest::SHA1.file(image).hexdigest }

  let(:attachment_path) { __FILE__ }
  let(:attachment) { File.new(attachment_path) }
  let(:attachment_filename) { File.basename(attachment_path) }
  let(:attachment_filesize) { File.size(attachment_path) }

  context ".create_thumbnail!" do

    it "does not create a thumbnail when disabled" do
      SiteSetting.stubs(:create_thumbnails?).returns(false)
      OptimizedImage.expects(:create_for).never
      upload.create_thumbnail!(100, 100)
    end

    it "creates a thumbnail" do
      upload = Fabricate(:upload)
      thumbnail = Fabricate(:optimized_image, upload: upload)
      SiteSetting.expects(:create_thumbnails?).returns(true)
      OptimizedImage.expects(:create_for).returns(thumbnail)
      upload.create_thumbnail!(100, 100)
      upload.reload
      upload.optimized_images.count.should == 1
    end

  end

  context "#create_for" do

    it "does not create another upload if it already exists" do
      Upload.expects(:find_by).with(sha1: image_sha1).returns(upload)
      Upload.expects(:save).never
      Upload.create_for(user_id, image, image_filename, image_filesize).should == upload
    end

    it "computes width & height for images" do
      FastImage.any_instance.expects(:size).returns([100, 200])
      ImageSizer.expects(:resize)
      image.expects(:rewind).twice
      Upload.create_for(user_id, image, image_filename, image_filesize)
    end

    it "does not create an upload when there is an error with FastImage" do
      FileHelper.expects(:is_image?).returns(true)
      Upload.expects(:save).never
      upload = Upload.create_for(user_id, attachment, attachment_filename, attachment_filesize)
      upload.errors.size.should > 0
    end

    it "does not compute width & height for non-image" do
      FastImage.any_instance.expects(:size).never
      upload = Upload.create_for(user_id, attachment, attachment_filename, attachment_filesize)
      upload.errors.size.should > 0
    end

    it "saves proper information" do
      store = {}
      Discourse.expects(:store).returns(store)
      store.expects(:store_upload).returns(url)

      upload = Upload.create_for(user_id, image, image_filename, image_filesize)

      upload.user_id.should == user_id
      upload.original_filename.should == image_filename
      upload.filesize.should == image_filesize
      upload.sha1.should == image_sha1
      upload.width.should == 244
      upload.height.should == 66
      upload.url.should == url
    end

  end

  context ".get_from_url" do

    it "works when the file has been uploaded" do
      Upload.expects(:find_by).returns(nil).once
      Upload.get_from_url("/uploads/default/1/10387531.jpg")
    end

    it "works when using a cdn" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      Upload.expects(:find_by).with(url: "/uploads/default/1/02395732905.jpg").returns(nil).once
      Upload.get_from_url("http://my.cdn.com/uploads/default/1/02395732905.jpg")
    end

    it "works only when the file has been uploaded" do
      Upload.expects(:find_by).never
      Upload.get_from_url("http://domain.com/my/file.txt")
    end

  end

end
