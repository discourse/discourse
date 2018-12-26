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
      SiteSetting.create_thumbnails = false
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

  it "can reconstruct dimensions on demand" do
    upload = UploadCreator.new(huge_image, "image.png").create_for(user_id)

    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    upload = Upload.find(upload.id)

    expect(upload.width).to eq(64250)
    expect(upload.height).to eq(64250)

    upload.reload
    expect(upload.read_attribute(:width)).to eq(64250)

    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    expect(upload.thumbnail_width).to eq(500)
    expect(upload.thumbnail_height).to eq(500)
  end

  it "dimension calculation returns nil on missing image" do
    upload = UploadCreator.new(huge_image, "image.png").create_for(user_id)
    upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

    missing_url = "wrong_folder#{upload.url}"
    upload.update_columns(url: missing_url)
    expect(upload.thumbnail_height).to eq(nil)
    expect(upload.thumbnail_width).to eq(nil)
  end

  it "extracts file extension" do
    created_upload = UploadCreator.new(image, image_filename).create_for(user_id)
    expect(created_upload.extension).to eq("png")
  end

  it "should create an invalid upload when the filename is blank" do
    SiteSetting.authorized_extensions = "*"
    created_upload = UploadCreator.new(attachment, nil).create_for(user_id)
    expect(created_upload.valid?).to eq(false)
  end

  context ".get_from_url" do
    let(:sha1) { "10f73034616a796dfd70177dc54b6def44c4ba6f" }
    let(:upload) { Fabricate(:upload, sha1: sha1) }

    it "works when the file has been uploaded" do
      expect(Upload.get_from_url(upload.url)).to eq(upload)
    end

    describe 'for an extensionless url' do
      before do
        upload.update!(url: upload.url.sub('.png', ''))
        upload.reload
      end

      it 'should return the right upload' do
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end
    end

    describe 'for a url a tree' do
      before do
        upload.update!(url:
          Discourse.store.get_path_for(
            "original",
            16001,
            upload.sha1,
            ".#{upload.extension}"
          )
        )
      end

      it 'should return the right upload' do
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end
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
      expect { Upload.get_from_url("mailto:admin%40example.com") }.not_to raise_error
      expect { Upload.get_from_url("mailto:example") }.not_to raise_error
    end

    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }
      let(:path) { upload.url.sub(SiteSetting.Upload.s3_base_url, '') }

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_upload_bucket = "s3-upload-bucket"
        SiteSetting.s3_access_key_id = "some key"
        SiteSetting.s3_secret_access_key = "some secret key"
      end

      it "should return the right upload when using base url (not CDN) for s3" do
        upload
        expect(Upload.get_from_url(upload.url)).to eq(upload)
      end

      describe 'when using a cdn' do
        let(:s3_cdn_url) { 'https://mycdn.slowly.net' }

        before do
          SiteSetting.s3_cdn_url = s3_cdn_url
        end

        it "should return the right upload" do
          upload
          expect(Upload.get_from_url(URI.join(s3_cdn_url, path).to_s)).to eq(upload)
        end

        describe 'when upload bucket contains subfolder' do
          let(:url) { "#{SiteSetting.Upload.absolute_base_url}/path/path2#{path}" }

          before do
            SiteSetting.s3_upload_bucket = "s3-upload-bucket/path/path2"
          end

          it "should return the right upload" do
            upload
            expect(Upload.get_from_url(URI.join(s3_cdn_url, path).to_s)).to eq(upload)
          end
        end
      end

      it "should return the right upload when using one CDN for both s3 and assets" do
        begin
          original_asset_host = Rails.configuration.action_controller.asset_host
          cdn_url = 'http://my.cdn.com'
          Rails.configuration.action_controller.asset_host = cdn_url
          SiteSetting.s3_cdn_url = cdn_url
          upload

          expect(Upload.get_from_url(
            URI.join(cdn_url, path).to_s
          )).to eq(upload)
        ensure
          Rails.configuration.action_controller.asset_host = original_asset_host
        end
      end
    end
  end

  describe '.generate_digest' do
    it "should return the right digest" do
      expect(Upload.generate_digest(image.path)).to eq('bc975735dfc6409c1c2aa5ebf2239949bcbdbd65')
    end
  end

  describe '.short_url' do
    it "should generate a correct short url" do
      upload = Upload.new(sha1: 'bda2c513e1da04f7b4e99230851ea2aafeb8cc4e', extension: 'png')
      expect(upload.short_url).to eq('upload://r3AYqESanERjladb4vBB7VsMBm6.png')
    end
  end

  describe '.sha1_from_short_url' do
    it "should be able to look up sha1" do
      sha1 = 'bda2c513e1da04f7b4e99230851ea2aafeb8cc4e'

      expect(Upload.sha1_from_short_url('upload://r3AYqESanERjladb4vBB7VsMBm6.png')).to eq(sha1)
      expect(Upload.sha1_from_short_url('upload://r3AYqESanERjladb4vBB7VsMBm6')).to eq(sha1)
      expect(Upload.sha1_from_short_url('r3AYqESanERjladb4vBB7VsMBm6')).to eq(sha1)
    end

    it "should be able to look up sha1 even with leading zeros" do
      sha1 = '0000c513e1da04f7b4e99230851ea2aafeb8cc4e'
      expect(Upload.sha1_from_short_url('upload://1Eg9p8rrCURq4T3a6iJUk0ri6.png')).to eq(sha1)
    end
  end

  describe '#to_s' do
    it 'should return the right value' do
      expect(upload.to_s).to eq(upload.url)
    end
  end

end
