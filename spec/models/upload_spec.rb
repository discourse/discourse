require 'rails_helper'

describe Upload do

  let(:upload) { build(:upload) }
  let(:thumbnail) { build(:optimized_image, upload: upload) }

  let(:user_id) { 1 }
  let(:url) { "http://domain.com" }

  let(:image_filename) { "logo.png" }
  let(:image) { file_from_fixtures(image_filename) }
  let(:image_filesize) { File.size(image) }
  let(:image_sha1) { Upload.generate_digest(image) }

  let(:image_svg_filename) { "image.svg" }
  let(:image_svg) { file_from_fixtures(image_svg_filename) }
  let(:image_svg_filesize) { File.size(image_svg) }

  let(:huge_image_filename) { "huge.jpg" }
  let(:huge_image) { file_from_fixtures(huge_image_filename) }
  let(:huge_image_filesize) { File.size(huge_image) }

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
      expect(upload.optimized_images.count).to eq(1)
    end

  end

  context "#create_for" do

    before do
      Upload.stubs(:fix_image_orientation)
      ImageOptim.any_instance.stubs(:optimize_image!)
    end

    it "does not create another upload if it already exists" do
      Upload.expects(:find_by).with(sha1: image_sha1).returns(upload)
      Upload.expects(:save).never
      expect(Upload.create_for(user_id, image, image_filename, image_filesize)).to eq(upload)
    end

    it "ensures images isn't huge before processing it" do
      Upload.expects(:fix_image_orientation).never
      upload = Upload.create_for(user_id, huge_image, huge_image_filename, huge_image_filesize)
      expect(upload.errors.size).to be > 0
    end

    it "fix image orientation" do
      Upload.expects(:fix_image_orientation).with(image.path)
      Upload.create_for(user_id, image, image_filename, image_filesize)
    end

    it "computes width & height for images" do
      ImageSizer.expects(:resize)
      Upload.create_for(user_id, image, image_filename, image_filesize)
    end

    it "does not compute width & height for non-image" do
      FastImage.any_instance.expects(:size).never
      upload = Upload.create_for(user_id, attachment, attachment_filename, attachment_filesize)
      expect(upload.errors.size).to be > 0
    end

    it "generates an error when the image is too large" do
      SiteSetting.stubs(:max_image_size_kb).returns(1)
      upload = Upload.create_for(user_id, image, image_filename, image_filesize)
      expect(upload.errors.size).to be > 0
    end

    it "generates an error when the attachment is too large" do
      SiteSetting.stubs(:max_attachment_size_kb).returns(1)
      upload = Upload.create_for(user_id, attachment, attachment_filename, attachment_filesize)
      expect(upload.errors.size).to be > 0
    end

    it "saves proper information" do
      store = {}
      Discourse.expects(:store).returns(store)
      store.expects(:store_upload).returns(url)

      upload = Upload.create_for(user_id, image, image_filename, image_filesize)

      expect(upload.user_id).to eq(user_id)
      expect(upload.original_filename).to eq(image_filename)
      expect(upload.filesize).to eq(image_filesize)
      expect(upload.width).to eq(244)
      expect(upload.height).to eq(66)
      expect(upload.url).to eq(url)
    end

    context "when svg is authorized" do

      before { SiteSetting.stubs(:authorized_extensions).returns("svg") }

      it "consider SVG as an image" do
        store = {}
        Discourse.expects(:store).returns(store)
        store.expects(:store_upload).returns(url)

        upload = Upload.create_for(user_id, image_svg, image_svg_filename, image_svg_filesize)

        expect(upload.user_id).to eq(user_id)
        expect(upload.original_filename).to eq(image_svg_filename)
        expect(upload.filesize).to eq(image_svg_filesize)
        expect(upload.width).to eq(100)
        expect(upload.height).to eq(50)
        expect(upload.url).to eq(url)
      end

    end

  end

  context ".get_from_url" do
    let(:url) { "/uploads/default/original/3X/1/0/10f73034616a796dfd70177dc54b6def44c4ba6f.png" }
    let(:upload) { Fabricate(:upload, url: url) }

    it "works when the file has been uploaded" do
      expect(Upload.get_from_url(upload.url)).to eq(upload)
    end

    it "works when using a cdn" do
      begin
        original_asset_host = Rails.configuration.action_controller.asset_host
        Rails.configuration.action_controller.asset_host = 'http://my.cdn.com'

        expect(Upload.get_from_url(
          URI.join("http://my.cdn.com", upload.url).to_s
        )).to eq(upload)
      ensure
        Rails.configuration.action_controller.asset_host = original_asset_host
      end
    end

    it "should return the right upload when using the full URL" do
      expect(Upload.get_from_url(
        URI.join("http://discourse.some.com:3000/", upload.url).to_s
      )).to eq(upload)
    end

    it "doesn't blow up with an invalid URI" do
      expect { Upload.get_from_url("http://ip:port/index.html") }.not_to raise_error
    end

    describe "s3 store" do
      let(:path) { "/original/3X/1/0/10f73034616a796dfd70177dc54b6def44c4ba6f.png" }
      let(:url) { "//#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com#{path}" }

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "some key"
        SiteSetting.s3_secret_access_key = "some secret key"
      end

      after do
        SiteSetting.enable_s3_uploads = false
      end

      it "should return the right upload when using a CDN for s3" do
        upload
        s3_cdn_url = 'https://mycdn.slowly.net'
        SiteSetting.s3_cdn_url = s3_cdn_url

        expect(Upload.get_from_url(URI.join(s3_cdn_url, path).to_s)).to eq(upload)
      end
    end
  end

  describe '.generate_digest' do
    it "should return the right digest" do
      expect(Upload.generate_digest(image.path)).to eq('bc975735dfc6409c1c2aa5ebf2239949bcbdbd65')
    end
  end

end
