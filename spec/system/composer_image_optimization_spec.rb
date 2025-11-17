# frozen_string_literal: true

describe "Composer image optimization for uploads using media-optimization-worker" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }
  let(:cdp) { PageObjects::CDP.new }

  before do
    sign_in(current_user)
    SiteSetting.composer_media_optimization_debug_mode = true
    SiteSetting.enable_upload_debug_mode = true

    # 1 byte to ensure all images are optimized in tests
    SiteSetting.composer_media_optimization_image_bytes_optimization_threshold = 1

    # Disable server-side optimizations
    SiteSetting.png_to_jpg_quality = 100
  end

  describe "jpeg images" do
    it "optimizes an uploaded jpeg image in the composer" do
      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("huge.jpg", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path))

      # Original huge.jpg is 466_479 bytes
      expect(upload.filesize).to eq(22_302)
    end

    it "skips resizing the image if its width is < composer_media_optimization_image_resize_dimensions_threshold" do
      SiteSetting.composer_media_optimization_image_resize_dimensions_threshold = 100

      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("logo.jpg", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path))

      # Original logo.jpg is 29_327 bytes, weirdly resizing this one causes it to increase in size
      expect(upload.filesize).to eq(143_862)

      # Re-upload without resizing
      SiteSetting.composer_media_optimization_image_resize_dimensions_threshold = 20_000

      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("logo.jpg", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path))

      # Original logo.jpg is 29_327 bytes
      expect(upload.filesize).to eq(26_182)
    end
  end

  describe "png images" do
    it "optimizes an uploaded png image in the composer" do
      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("large_and_unoptimized_notransparent.png", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path).gsub("png", "jpg"))

      # Original large_and_unoptimized_notransparent.png is 465_321 bytes
      expect(upload.filesize).to eq(285_850)
    end

    it "does not optimize a png with transparent pixels in the composer" do
      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("large_and_unoptimized.png", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path))

      # Original large_and_unoptimized.png is 421_730 bytes
      expect(upload.filesize).to eq(421_730)
    end
  end
end
