# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  describe ".image_quality" do
    it "retains JPEG quantization estimates" do
      {
        "exif_orientation.jpg" => 95,
        "logo.jpg" => 94,
        "huge.jpg" => 80,
      }.each do |filename, expected|
        result =
          described_class.image_quality(
            input_path: file_from_fixtures(filename).path,
            input_format: "jpeg",
            timeout: 5,
          )

        expect(result).to eq(expected)
      end
    end

    it "preserves unknown-quality defaults and concatenated frame estimates" do
      %w[
        static.gif
        animated.gif
        static.avif
        multipage.avif
        smallest.ico
        ico-last-png.ico
      ].each do |filename|
        input_path = file_from_fixtures(filename).path
        input_format = File.extname(filename).delete_prefix(".")
        expected = ImageMagick.image_quality(input_path:, timeout: 5)

        result = described_class.image_quality(input_path:, input_format:, timeout: 5)

        expect(result).to eq(expected), filename
      end
    end

    it "returns the unknown-quality default for SVG" do
      result =
        described_class.image_quality(
          input_path: file_from_fixtures("image.svg").path,
          input_format: "svg",
          timeout: 5,
        )

      expect(result).to eq(92)
    end

    it "distinguishes lossy and lossless WebP frames" do
      Dir.mktmpdir do |directory|
        input_path = file_from_fixtures("tiny_animated.gif").path
        [false, true].each do |lossless|
          output_path = File.join(directory, "animation.webp")
          image = Vips::Image.gifload(input_path, n: -1)
          image.webpsave(output_path, lossless:)
          expected = ImageMagick.image_quality(input_path: output_path, timeout: 5)

          result =
            described_class.image_quality(input_path: output_path, input_format: "webp", timeout: 5)

          expect(result).to eq(expected)
        end
      end
    end

    it "preserves first-frame WebP quality inheritance" do
      {
        "webp-quality-first-frame.webp" => 100_100,
        "webp-quality-later-frame.webp" => 9_210_092,
      }.each do |filename, expected|
        input_path = file_from_fixtures(filename).path

        result = described_class.image_quality(input_path:, input_format: "webp", timeout: 5)

        expect(result).to eq(expected)
        expect(ImageMagick.image_quality(input_path:, timeout: 5)).to eq(expected)
      end
    end

    it "rejects a mismatched typed input" do
      expect do
        described_class.image_quality(
          input_path: file_from_fixtures("logo.jpg").path,
          input_format: "png",
          timeout: 5,
        )
      end.to raise_error(DiscourseVips::InvalidImage)
    end

    it "rejects unsupported formats" do
      expect do
        described_class.image_quality(
          input_path: file_from_fixtures("logo.jpg").path,
          input_format: "pdf",
          timeout: 5,
        )
      end.to raise_error(DiscourseVips::InvalidImage, /unsupported input format/)
    end

    it "rejects malformed image bytes" do
      expect do
        described_class.image_quality(
          input_path: file_from_fixtures("fake.jpg").path,
          input_format: "jpeg",
          timeout: 5,
        )
      end.to raise_error(DiscourseVips::InvalidImage)
    end
  end
end
