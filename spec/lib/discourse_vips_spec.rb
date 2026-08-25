# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns a cache version" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+-8\.\d+\.\d+\z/)
    end
  end

  describe ".generate_letter_avatar" do
    it "generates a 360 by 360 PNG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "avatar.png")

        described_class.generate_letter_avatar(
          letter: "<",
          background_color: [198, 125, 40],
          output_path:,
        )

        expect(FastImage.type(output_path)).to eq(:png)
        expect(FastImage.size(output_path)).to eq([360, 360])
      end
    end
  end

  describe ".dominant_color" do
    it "returns an uppercase RGB hex color" do
      input_path = file_from_fixtures("cropped.png").path

      expect(described_class.dominant_color(input_path:)).to eq("171613")
    end

    it "rejects unsupported image content" do
      input_path = file_from_fixtures("image.svg").path

      expect { described_class.dominant_color(input_path:) }.to raise_error(
        DiscourseVips::Error,
        /unsupported input format/,
      )
    end
  end

  describe ".generate_topic_og_image" do
    it "generates a PNG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "topic.png")
        svg_path = file_from_fixtures("image.svg").path

        described_class.generate_topic_og_image(svg_path:, output_path:, max_pixels: 40_000_000)

        expect(FastImage.type(output_path)).to eq(:png)
      end
    end

    it "rejects raster input" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        expect {
          described_class.generate_topic_og_image(
            svg_path: file_from_fixtures("logo.png").path,
            output_path: File.join(directory, "topic.png"),
            max_pixels: 40_000_000,
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end
  end
end
