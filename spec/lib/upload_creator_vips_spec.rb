# frozen_string_literal: true

RSpec.describe UploadCreator do
  fab!(:user)

  def write_oriented_jpeg(source:, target:, orientation:)
    Vips.call(
      "copy",
      source,
      "#{target}[Q=82,strip=true]",
      read: [source],
      write: [File.dirname(target)],
    )

    jpeg = File.binread(target)
    tiff =
      "II".b + [42].pack("v") + [8].pack("V") + [1].pack("v") + [0x0112, 3].pack("v2") +
        [1].pack("V") + [orientation, 0].pack("v2") + [0].pack("V")
    payload = "Exif\0\0".b + tiff
    segment = "\xFF\xE1".b + [payload.bytesize + 2].pack("n") + payload
    File.binwrite(target, jpeg.byteslice(0, 2) + segment + jpeg.byteslice(2..))
  end

  def jpeg_quality(path)
    Discourse::Utils.execute_command("identify", "-ping", "-format", "%Q", path).to_i
  end

  def create_metadata_png_upload
    tempfile = Tempfile.new(%w[metadata .png])
    source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
    Vips.call(
      "copy",
      source,
      "#{tempfile.path}[compression=0]",
      read: [source],
      write: [File.dirname(tempfile.path)],
    )
    tempfile.rewind

    described_class.new(tempfile, "metadata.png", pasted: true, force_optimize: true).create_for(
      user.id,
    )
  end

  def metadata_presence(path)
    %w[exif-data xmp-data iptc-data icc-profile-data].to_h do |field|
      present = Vips.header(path, field:).present?
      [field, present]
    rescue Discourse::Utils::CommandError
      [field, false]
    end
  end

  before do
    SiteSetting.use_vips_for_image_processing = true
    ImageMagick.stubs(:magick).raises("ImageMagick must not run")
    ImageMagick.stubs(:identify).raises("ImageMagick must not run")
  end

  describe "#create_for" do
    it "converts pasted PNG uploads to JPEG with vips" do
      SiteSetting.png_to_jpg_quality = 1

      upload =
        described_class.new(
          file_from_fixtures("should_be_jpeg.png"),
          "should_be_jpeg.png",
          pasted: true,
          force_optimize: true,
        ).create_for(user.id)
      path = Discourse.store.path_for(upload)

      expect(
        {
          persisted: upload.persisted?,
          extension: upload.extension,
          filename: upload.original_filename,
          format: FastImage.type(path),
          dimensions: FastImage.size(path),
          quality: jpeg_quality(path),
        },
      ).to eq(
        {
          persisted: true,
          extension: "jpeg",
          filename: "should_be_jpeg.jpg",
          format: :jpeg,
          dimensions: [303, 231],
          quality: 1,
        },
      )
    end

    it "keeps only EXIF and ICC when metadata stripping is disabled" do
      SiteSetting.png_to_jpg_quality = 80
      SiteSetting.composer_media_optimization_image_enabled = false

      [true, false].each do |strip_metadata|
        SiteSetting.strip_image_metadata = strip_metadata
        vips_upload = create_metadata_png_upload
        vips_metadata = metadata_presence(Discourse.store.path_for(vips_upload))

        expect(vips_metadata).to eq(
          {
            "exif-data" => !strip_metadata,
            "xmp-data" => false,
            "iptc-data" => false,
            "icc-profile-data" => !strip_metadata,
          },
        )
      end
    end

    it "converts HEIC uploads to JPEG with vips" do
      upload =
        described_class.new(
          file_from_fixtures("should_be_jpeg.heic"),
          "should_be_jpeg.heic",
          force_optimize: true,
        ).create_for(user.id)
      path = Discourse.store.path_for(upload)

      expect(
        {
          persisted: upload.persisted?,
          extension: upload.extension,
          filename: upload.original_filename,
          format: FastImage.type(path),
          dimensions: FastImage.size(path),
        },
      ).to eq(
        {
          persisted: true,
          extension: "jpeg",
          filename: "should_be_jpeg.jpg",
          format: :jpeg,
          dimensions: [846, 1129],
        },
      )
    end

    it "propagates the stock-vips ICO loader failure without ImageMagick fallback" do
      SiteSetting.authorized_extensions = "png|jpg|ico"
      Vips.stubs(:convert).raises(Discourse::Utils::CommandError.new("vips has no ICO loader"))

      expect do
        described_class.new(file_from_fixtures("smallest.ico"), "smallest.ico").create_for(user.id)
      end.to raise_error(Discourse::Utils::CommandError, "vips has no ICO loader")
    end

    it "preserves ImageMagick-compatible SVG dimensions" do
      expected_dimensions = {
        "tiny.svg" => [115, 86],
        "massive.svg" => [11_520, 11_615],
        "zero_sized.svg" => [120, 90],
      }
      dimensions =
        expected_dimensions.to_h do |filename, _expected|
          upload =
            described_class.new(
              file_from_fixtures(filename),
              filename,
              force_optimize: true,
            ).create_for(user.id)
          [filename, [upload.width, upload.height]]
        end

      expect(dimensions).to eq(expected_dimensions)
    end

    it "uses vips frame counts when FastImage cannot classify animations" do
      FastImage.stubs(:animated?).returns(nil)

      uploads =
        %w[animated.gif animated.webp].to_h do |filename|
          upload =
            described_class.new(
              file_from_fixtures(filename),
              filename,
              force_optimize: true,
            ).create_for(user.id)
          path = Discourse.store.path_for(upload)
          [
            filename,
            { animated: upload.animated, frames: Vips.frame_count(path, format: upload.extension) },
          ]
        end

      expect(uploads).to eq(
        "animated.gif" => {
          animated: true,
          frames: 20,
        },
        "animated.webp" => {
          animated: true,
          frames: 67,
        },
      )
    end

    it "rewrites EXIF-oriented JPEG pixels upright with vips" do
      tempfile = Tempfile.new(%w[oriented .jpg])
      source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
      write_oriented_jpeg(source:, target: tempfile.path, orientation: 6)
      tempfile.rewind

      upload =
        described_class.new(tempfile, "oriented.jpg", force_optimize: true).create_for(user.id)
      path = Discourse.store.path_for(upload)

      expect(
        {
          dimensions: FastImage.size(path),
          rotated: Vips.rotated?(path, format: "jpeg"),
          quality: jpeg_quality(path),
        },
      ).to eq(dimensions: [1312, 2032], rotated: false, quality: 90)
    end

    it "uses the configured JPEG quality when re-encoding" do
      tempfile = Tempfile.new(%w[quality .jpg])
      source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
      Vips.call(
        "copy",
        source,
        "#{tempfile.path}[Q=90]",
        read: [source],
        write: [File.dirname(tempfile.path)],
      )
      tempfile.rewind
      SiteSetting.recompress_original_jpg_quality = 40

      upload =
        described_class.new(tempfile, "quality.jpg", force_optimize: true).create_for(user.id)

      expect(jpeg_quality(Discourse.store.path_for(upload))).to eq(40)
    end

    it "propagates a vips conversion failure without a debug retry or ImageMagick fallback" do
      Vips.stubs(:convert).raises(Discourse::Utils::CommandError.new("vips failed"))

      expect do
        described_class.new(
          file_from_fixtures("should_be_jpeg.heic"),
          "should_be_jpeg.heic",
          force_optimize: true,
        ).create_for(user.id)
      end.to raise_error(Discourse::Utils::CommandError, "vips failed")
    end
  end
end
