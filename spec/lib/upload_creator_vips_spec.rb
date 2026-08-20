# frozen_string_literal: true

RSpec.describe UploadCreator do
  fab!(:user)

  def write_oriented_jpeg(source:, target:, orientation:)
    Vips.run(
      "vips",
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

  def create_metadata_png_upload
    tempfile = Tempfile.new(%w[metadata .png])
    source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
    Vips.run(
      "vips",
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
      present = Vips.run("vipsheader", "--field", field, path, read: [path]).present?
      [field, present]
    rescue Discourse::Utils::CommandError
      [field, false]
    end
  end

  before { SiteSetting.use_vips_for_image_processing = true }

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
        },
      ).to eq(
        {
          persisted: true,
          extension: "jpeg",
          filename: "should_be_jpeg.jpg",
          format: :jpeg,
          dimensions: [303, 231],
        },
      )
    end

    it "keeps exposed metadata under the disabled metadata-stripping setting" do
      SiteSetting.png_to_jpg_quality = 80
      SiteSetting.composer_media_optimization_image_enabled = false

      [true, false].each do |strip_metadata|
        SiteSetting.strip_image_metadata = strip_metadata
        vips_upload = create_metadata_png_upload
        vips_metadata = metadata_presence(Discourse.store.path_for(vips_upload))

        expect(vips_metadata).to eq(
          {
            "exif-data" => !strip_metadata,
            "xmp-data" => !strip_metadata,
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

    it "raises the stock-vips ICO loader error and does not start ImageMagick" do
      SiteSetting.authorized_extensions = "png|jpg|ico"

      expect do
        described_class.new(file_from_fixtures("smallest.ico"), "smallest.ico").create_for(user.id)
      end.to raise_error(Discourse::Utils::CommandError)
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

    it "uses vips frame counts for animations that FastImage cannot classify" do
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
          frames =
            Vips.run(
              "vipsheader",
              "--field",
              "n-pages",
              path,
              read: [path],
              timeout: Upload::MAX_IDENTIFY_SECONDS,
            ).to_i
          [filename, { animated: upload.animated, frames: }]
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

    it "rewrites every EXIF orientation to upright pixels" do
      source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
      SiteSetting.composer_media_optimization_image_enabled = false
      SiteSetting.strip_image_metadata = false

      results =
        (2..8).to_h do |orientation|
          tempfile = Tempfile.new(["oriented-#{orientation}", ".jpg"])
          write_oriented_jpeg(source:, target: tempfile.path, orientation:)
          tempfile.rewind

          upload =
            described_class.new(
              tempfile,
              "oriented-#{orientation}.jpg",
              force_optimize: true,
            ).create_for(user.id)
          path = Discourse.store.path_for(upload)
          output_orientation =
            Vips.run("vipsheader", "--field", "orientation", path, read: [path]).to_i

          [
            orientation,
            {
              dimensions: FastImage.size(path),
              upload_dimensions: [upload.width, upload.height],
              orientation: output_orientation,
              digest_matches: Upload.generate_digest(path) == upload.sha1,
            },
          ]
        end

      expect(results).to eq(
        {
          2 => {
            dimensions: [2032, 1312],
            upload_dimensions: [2032, 1312],
            orientation: 1,
            digest_matches: true,
          },
          3 => {
            dimensions: [2032, 1312],
            upload_dimensions: [2032, 1312],
            orientation: 1,
            digest_matches: true,
          },
          4 => {
            dimensions: [2032, 1312],
            upload_dimensions: [2032, 1312],
            orientation: 1,
            digest_matches: true,
          },
          5 => {
            dimensions: [1312, 2032],
            upload_dimensions: [1312, 2032],
            orientation: 1,
            digest_matches: true,
          },
          6 => {
            dimensions: [1312, 2032],
            upload_dimensions: [1312, 2032],
            orientation: 1,
            digest_matches: true,
          },
          7 => {
            dimensions: [1312, 2032],
            upload_dimensions: [1312, 2032],
            orientation: 1,
            digest_matches: true,
          },
          8 => {
            dimensions: [1312, 2032],
            upload_dimensions: [1312, 2032],
            orientation: 1,
            digest_matches: true,
          },
        },
      )
    end

    it "keeps the cropped upload metadata consistent with the stored file" do
      upload =
        described_class.new(
          file_from_fixtures("large_and_unoptimized.png"),
          "avatar.png",
          type: "avatar",
          force_optimize: true,
        ).create_for(user.id)
      path = Discourse.store.path_for(upload)

      expect(
        {
          persisted: upload.persisted?,
          upload_dimensions: [upload.width, upload.height],
          file_dimensions: FastImage.size(path),
          digest_matches: Upload.generate_digest(path) == upload.sha1,
        },
      ).to eq(
        {
          persisted: true,
          upload_dimensions: [288, 288],
          file_dimensions: [288, 288],
          digest_matches: true,
        },
      )
    end

    it "produces smaller files at lower configured JPEG quality" do
      source = Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s
      encoded_sizes =
        [40, 80].to_h do |quality|
          tempfile = Tempfile.new(%W[quality-#{quality} .jpg])
          Vips.run(
            "vips",
            "copy",
            source,
            "#{tempfile.path}[Q=90]",
            read: [source],
            write: [File.dirname(tempfile.path)],
          )
          tempfile.rewind
          SiteSetting.recompress_original_jpg_quality = quality

          upload =
            described_class.new(
              tempfile,
              "quality-#{quality}.jpg",
              force_optimize: true,
            ).create_for(user.id)
          [quality, File.size(Discourse.store.path_for(upload))]
        end

      expect(encoded_sizes.fetch(40)).to be < encoded_sizes.fetch(80)
    end

    it "raises the first vips conversion error and does not start ImageMagick" do
      Vips.stubs(:run).raises(Discourse::Utils::CommandError.new("vips failed"))

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
