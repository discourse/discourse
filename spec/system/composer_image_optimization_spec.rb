# frozen_string_literal: true

describe "Composer image optimization for uploads using media-optimization-worker" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }

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

      file = file_from_fixtures("large_and_unoptimized.png", "images")
      converted_file_path = file.path.gsub("unoptimized", "notransparent")

      # We do a conversion here to simulate a PNG with no transparency, the
      # fixture has transparency and transparent PNGs are converted to WEBP
      # rather than JPEG (see the transparent PNG test below).
      Discourse::Utils.execute_command(
        *["convert", file.path, "-background", "white", "-alpha", "remove", converted_file_path],
        timeout: 3,
      )

      attach_file("file-uploader", [converted_file_path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload =
        Upload.find_by(original_filename: File.basename(converted_file_path).gsub("png", "jpg"))

      # Original large_and_unoptimized PNG with no transparency is 312_889 bytes
      expect(upload.filesize).to eq(271_246)
    ensure
      FileUtils.rm(converted_file_path)
    end

    it "converts a png with transparent pixels to webp in the composer" do
      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("large_and_unoptimized.png", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path).gsub("png", "webp"))

      # Original large_and_unoptimized.png is 421_730 bytes and 2032px wide;
      # transparent PNGs are resized and re-encoded as WEBP instead of JPEG.
      expect(upload.filesize).to eq(126_626)
    end

    it "keeps the original transparent png when webp is not an authorized extension" do
      SiteSetting.authorized_extensions = "jpg|jpeg|png|gif"

      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("large_and_unoptimized.png", "images")
      attach_file("file-uploader", [file.path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(file.path))

      # Original large_and_unoptimized.png is 421_730 bytes, uploaded untouched
      # because converting it to WEBP would produce an unauthorized extension.
      expect(upload.filesize).to eq(421_730)
    end

    it "keeps an animated png untouched in the composer" do
      visit "/new-topic"
      expect(composer).to be_opened

      file = file_from_fixtures("large_and_unoptimized.png", "images")
      apng_path = file.path.gsub("unoptimized", "animated")

      # Emulate an APNG by inserting an acTL chunk right after IHDR; the
      # optimizer's decoder would only keep the first frame, so it must skip
      # animated PNGs entirely.
      png = File.binread(file.path)
      actl_data = [2, 0].pack("N2")
      actl_chunk =
        [actl_data.bytesize].pack("N") + "acTL" + actl_data +
          [Zlib.crc32("acTL" + actl_data)].pack("N")
      ihdr_end = 8 + 4 + 4 + 13 + 4 # signature + IHDR length/type/data/crc
      File.binwrite(apng_path, png[0...ihdr_end] + actl_chunk + png[ihdr_end..])

      attach_file("file-uploader", [apng_path], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".image-wrapper", count: 1)

      upload = Upload.find_by(original_filename: File.basename(apng_path))

      expect(upload.filesize).to eq(File.size(apng_path))
    ensure
      FileUtils.rm(apng_path)
    end
  end
end
