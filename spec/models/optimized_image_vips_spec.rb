# frozen_string_literal: true

require "chunky_png"

RSpec.describe OptimizedImage do
  let(:input) { Rails.root.join("spec/fixtures/images/large_and_unoptimized.png").to_s }

  def normalized_channel_error(first:, second:)
    first_image = ChunkyPNG::Image.from_file(first)
    second_image = ChunkyPNG::Image.from_file(second)
    raise ArgumentError if first_image.dimension != second_image.dimension

    error =
      first_image
        .pixels
        .zip(second_image.pixels)
        .sum do |first_pixel, second_pixel|
          [
            ChunkyPNG::Color.r(first_pixel) - ChunkyPNG::Color.r(second_pixel),
            ChunkyPNG::Color.g(first_pixel) - ChunkyPNG::Color.g(second_pixel),
            ChunkyPNG::Color.b(first_pixel) - ChunkyPNG::Color.b(second_pixel),
            ChunkyPNG::Color.a(first_pixel) - ChunkyPNG::Color.a(second_pixel),
          ].sum(&:abs)
        end

    error.fdiv(first_image.width * first_image.height * 4 * 255)
  end

  def vips_field_present?(path, field)
    Vips.run("vipsheader", "--field", field, path, read: [path]).present?
  rescue Discourse::Utils::CommandError
    false
  end

  def parity(operation:, arguments:)
    Dir.mktmpdir("optimized-image-parity") do |directory|
      image_magick_output = File.join(directory, "image-magick.png")
      vips_output = File.join(directory, "vips.png")

      SiteSetting.use_vips_for_image_processing = false
      described_class.public_send(operation, input, image_magick_output, *arguments)

      SiteSetting.use_vips_for_image_processing = true
      described_class.public_send(operation, input, vips_output, *arguments)

      yield image_magick_output, vips_output
    end
  end

  describe ".version" do
    it "uses distinct cache versions for each image processor" do
      image_magick_version = described_class.version
      SiteSetting.use_vips_for_image_processing = true

      expect({ image_magick: image_magick_version, vips: described_class.version }).to eq(
        { image_magick: OptimizedImage::VERSION, vips: OptimizedImage::VIPS_VERSION },
      )
    end
  end

  describe ".resize" do
    it "keeps the ImageMagick path under the disabled setting" do
      Dir.mktmpdir("optimized-image-selector") do |directory|
        output = File.join(directory, "output.png")

        expect(described_class.resize(input, output, 321, 123)).to eq(true)
        expect(FastImage.size(output)).to eq([321, 123])
      end
    end

    it "uses vips under the enabled setting" do
      Dir.mktmpdir("optimized-image-selector") do |directory|
        output = File.join(directory, "output.png")
        SiteSetting.use_vips_for_image_processing = true

        expect(described_class.resize(input, output, 321, 123)).to eq(true)
        expect(FastImage.size(output)).to eq([321, 123])
      end
    end

    it "processes every eligible raster format through the public resize API" do
      Dir.mktmpdir("optimized-image-formats") do |directory|
        source_directory = Rails.root.join("spec/fixtures/images")
        inputs = {
          jpeg: source_directory.join("logo.jpg").to_s,
          png: input,
          gif: source_directory.join("animated.gif").to_s,
          webp: source_directory.join("animated.webp").to_s,
        }
        avif = File.join(directory, "input.avif")
        Vips.run("vips", "copy", input, avif, read: [input], write: [directory])
        inputs[:avif] = avif
        SiteSetting.use_vips_for_image_processing = true

        dimensions =
          inputs.to_h do |format, source|
            output = File.join(directory, "output.#{format}")
            expect(described_class.resize(source, output, 96, 64, raise_on_error: true)).to eq(true)
            [format, FastImage.size(output)]
          end

        expect(dimensions).to eq(inputs.transform_values { [96, 64] })
      end
    end

    it "does not fall back to ImageMagick after a vips failure" do
      Dir.mktmpdir("optimized-image-failure") do |directory|
        malformed = File.join(directory, "malformed.png")
        output = File.join(directory, "output.png")
        File.binwrite(malformed, "not an image")
        File.binwrite(output, "existing output")
        SiteSetting.use_vips_for_image_processing = true

        expect do
          described_class.resize(malformed, output, 50, 50, raise_on_error: true)
        end.to raise_error(Discourse::Utils::CommandError)
        expect(File.binread(output)).to eq("existing output")
      end
    end

    it "preserves or strips source metadata according to the site setting" do
      Dir.mktmpdir("optimized-image-metadata") do |directory|
        preserved = File.join(directory, "preserved.png")
        stripped = File.join(directory, "stripped.png")
        SiteSetting.use_vips_for_image_processing = true
        SiteSetting.composer_media_optimization_image_enabled = false

        SiteSetting.strip_image_metadata = false
        described_class.resize(input, preserved, 320, 200)

        SiteSetting.strip_image_metadata = true
        described_class.resize(input, stripped, 320, 200)

        expect(
          {
            preserved_xmp: vips_field_present?(preserved, "xmp-data"),
            preserved_profile: vips_field_present?(preserved, "icc-profile-data"),
            stripped_xmp: vips_field_present?(stripped, "xmp-data"),
            stripped_profile: vips_field_present?(stripped, "icc-profile-data"),
          },
        ).to eq(
          preserved_xmp: true,
          preserved_profile: true,
          stripped_xmp: false,
          stripped_profile: false,
        )
      end
    end

    it "uses the output format, quality, and palette options" do
      Dir.mktmpdir("optimized-image-options") do |directory|
        low_quality = File.join(directory, "low-quality.jpg")
        high_quality = File.join(directory, "high-quality.jpg")
        image_magick_palette = File.join(directory, "image-magick-palette.png")
        vips_palette = File.join(directory, "vips-palette.png")

        described_class.resize(input, image_magick_palette, 321, 123, colors: 12)
        SiteSetting.use_vips_for_image_processing = true

        described_class.resize(input, low_quality, 321, 123, format: "jpg", quality: 35)
        described_class.resize(input, high_quality, 321, 123, format: "jpg", quality: 90)
        described_class.resize(input, vips_palette, 321, 123, colors: 12)

        image_magick_palette_colors =
          ChunkyPNG::Image.from_file(image_magick_palette).pixels.uniq.length
        vips_palette_colors = ChunkyPNG::Image.from_file(vips_palette).pixels.uniq.length

        expect(
          {
            low_quality_format: FastImage.type(low_quality),
            high_quality_format: FastImage.type(high_quality),
            lower_quality_is_smaller: File.size(low_quality) < File.size(high_quality),
            vips_palette_not_larger: vips_palette_colors <= image_magick_palette_colors,
            image_magick_palette_colors:,
            vips_palette_encoded:
              ChunkyPNG::Datastream.from_file(vips_palette).palette_chunk.present?,
          },
        ).to match(
          {
            low_quality_format: :jpeg,
            high_quality_format: :jpeg,
            lower_quality_is_smaller: true,
            vips_palette_not_larger: true,
            image_magick_palette_colors: be <= 256,
            vips_palette_encoded: true,
          },
        )
      end
    end

    it "stays within the visual and encoded-size parity thresholds" do
      parity(operation: :resize, arguments: [321, 123]) do |image_magick_output, vips_output|
        expect(
          {
            dimensions: [FastImage.size(image_magick_output), FastImage.size(vips_output)],
            channel_error:
              normalized_channel_error(first: image_magick_output, second: vips_output),
            size_ratio: File.size(vips_output).fdiv(File.size(image_magick_output)),
          },
        ).to match(
          {
            dimensions: [[321, 123], [321, 123]],
            channel_error: be <= 0.03,
            size_ratio: be_between(0.5, 2.0),
          },
        )
      end
    end
  end

  describe ".crop" do
    it "produces an exact north-gravity crop for an uncommon aspect ratio" do
      Dir.mktmpdir("optimized-image-crop") do |directory|
        output = File.join(directory, "output.png")
        SiteSetting.use_vips_for_image_processing = true

        expect(described_class.crop(input, output, 173, 419)).to eq(true)
        expect(FastImage.size(output)).to eq([173, 419])
      end
    end

    it "stays within the north-crop visual and encoded-size parity thresholds" do
      parity(operation: :crop, arguments: [321, 123]) do |image_magick_output, vips_output|
        expect(
          {
            dimensions: [FastImage.size(image_magick_output), FastImage.size(vips_output)],
            channel_error:
              normalized_channel_error(first: image_magick_output, second: vips_output),
            size_ratio: File.size(vips_output).fdiv(File.size(image_magick_output)),
          },
        ).to match(
          {
            dimensions: [[321, 123], [321, 123]],
            channel_error: be <= 0.03,
            size_ratio: be_between(0.5, 2.0),
          },
        )
      end
    end
  end

  describe ".downsize" do
    it "preserves aspect ratio for percentage, area, and shrink-only geometries" do
      Dir.mktmpdir("optimized-image-downsize") do |directory|
        percentage = File.join(directory, "percentage.png")
        area = File.join(directory, "area.png")
        shrink_only = File.join(directory, "shrink-only.png")
        transparent_input = Rails.root.join("spec/fixtures/images/logo.png").to_s
        SiteSetting.use_vips_for_image_processing = true

        described_class.downsize(input, percentage, "50%")
        described_class.downsize(input, area, "500000@")
        described_class.downsize(transparent_input, shrink_only, "500x500>")

        area_width, area_height = FastImage.size(area)
        transparent_pixel =
          Vips.run("vips", "getpoint", shrink_only, "0", "0", read: [shrink_only]).split.map(&:to_f)

        expect(
          {
            percentage: FastImage.size(percentage),
            area_within_limit: area_width * area_height <= 500_000,
            shrink_only: FastImage.size(shrink_only),
            transparent_bands:
              Vips.run("vipsheader", "--field", "bands", shrink_only, read: [shrink_only]).to_i,
            transparent_alpha: transparent_pixel.last,
          },
        ).to match(
          {
            percentage: [1016, 656],
            area_within_limit: true,
            shrink_only: [244, 66],
            transparent_bands: 4,
            transparent_alpha: 0,
          },
        )
      end
    end

    it "stays within the shrink-only visual and encoded-size parity thresholds" do
      parity(operation: :downsize, arguments: ["333x222>"]) do |image_magick_output, vips_output|
        expect(
          {
            dimensions: [FastImage.size(image_magick_output), FastImage.size(vips_output)],
            channel_error:
              normalized_channel_error(first: image_magick_output, second: vips_output),
            size_ratio: File.size(vips_output).fdiv(File.size(image_magick_output)),
          },
        ).to match(
          {
            dimensions: [[333, 215], [333, 215]],
            channel_error: be <= 0.03,
            size_ratio: be_between(0.5, 2.0),
          },
        )
      end
    end
  end

  describe ".create_for" do
    it "does not reuse optimized images across processor versions" do
      upload =
        UploadCreator.new(file_from_fixtures("logo.png"), "logo.png").create_for(
          Discourse.system_user.id,
        )
      image_magick = described_class.create_for(upload, 50, 50)

      SiteSetting.use_vips_for_image_processing = true
      vips = described_class.create_for(upload, 50, 50)

      expect(
        {
          distinct_records: image_magick.id != vips.id,
          image_magick_version: image_magick.version,
          vips_version: vips.version,
        },
      ).to eq(
        {
          distinct_records: true,
          image_magick_version: OptimizedImage::VERSION,
          vips_version: OptimizedImage::VIPS_VERSION,
        },
      )
    ensure
      vips&.destroy
      upload&.destroy
    end
  end
end
