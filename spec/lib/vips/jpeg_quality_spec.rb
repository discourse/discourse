# frozen_string_literal: true

RSpec.describe Vips::JpegQuality do
  describe ".read" do
    it "returns the encoder quality across the supported range" do
      Dir.mktmpdir("vips-jpeg-quality") do |directory|
        source = Rails.root.join("spec/fixtures/images/logo.jpg").to_s
        qualities = [1, 10, 25, 40, 60, 75, 85, 92, 100]

        detected =
          qualities.to_h do |quality|
            output = File.join(directory, "quality-#{quality}.jpg")
            Vips.call("copy", source, "#{output}[Q=#{quality}]", read: [source], write: [directory])
            [
              quality,
              {
                parser: described_class.read(output),
                image_magick:
                  ImageMagick.identify(
                    "-ping",
                    "-format",
                    "%Q",
                    output,
                    read: [output],
                    timeout: Upload::MAX_IDENTIFY_SECONDS,
                  ).to_i,
              },
            ]
          end

        expect(detected).to eq(
          qualities.to_h { |quality| [quality, { parser: quality, image_magick: quality }] },
        )
      end
    end

    it "returns zero for malformed and truncated JPEG data" do
      Dir.mktmpdir("vips-jpeg-quality") do |directory|
        malformed = File.join(directory, "malformed.jpg")
        truncated = File.join(directory, "truncated.jpg")
        File.binwrite(malformed, "not a jpeg")
        File.binwrite(truncated, "\xFF\xD8\xFF\xDB\x00\x43".b)

        expect(
          {
            malformed: described_class.read(malformed),
            truncated: described_class.read(truncated),
          },
        ).to eq(malformed: 0, truncated: 0)
      end
    end
  end
end
