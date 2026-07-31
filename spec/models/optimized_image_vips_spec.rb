# frozen_string_literal: true

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
    it "keeps the ImageMagick path when the setting is disabled" do
      Dir.mktmpdir("optimized-image-selector") do |directory|
        output = File.join(directory, "output.png")

        expect(described_class.resize(input, output, 321, 123)).to eq(true)
        expect(FastImage.size(output)).to eq([321, 123])
      end
    end

    it "uses vips when the setting is enabled" do
      Dir.mktmpdir("optimized-image-selector") do |directory|
        output = File.join(directory, "output.png")
        SiteSetting.use_vips_for_image_processing = true

        expect(described_class.resize(input, output, 321, 123)).to eq(true)
        expect(FastImage.size(output)).to eq([321, 123])
      end
    end

    it "does not fall back to ImageMagick after a vips failure" do
      Dir.mktmpdir("optimized-image-failure") do |directory|
        malformed = File.join(directory, "malformed.png")
        output = File.join(directory, "output.png")
        File.binwrite(malformed, "not an image")
        SiteSetting.use_vips_for_image_processing = true

        expect do
          described_class.resize(malformed, output, 50, 50, raise_on_error: true)
        end.to raise_error(Discourse::Utils::CommandError)
        expect(File.exist?(output)).to eq(false)
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
          avatar_version: UserAvatar.version(upload.id),
        },
      ).to eq(
        {
          distinct_records: true,
          image_magick_version: OptimizedImage::VERSION,
          vips_version: OptimizedImage::VIPS_VERSION,
          avatar_version: "#{upload.id}_#{OptimizedImage::VIPS_VERSION}",
        },
      )
    ensure
      vips&.destroy
      upload&.destroy
    end
  end
end
