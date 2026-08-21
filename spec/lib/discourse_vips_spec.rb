# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns the helper and libvips version" do
      expect(described_class.version).to match(/\A1-8\.\d+\.\d+\z/)
    end

    it "fails closed without Landlock outside local environments" do
      Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("production"))
      Discourse::SafeExec.stubs(landlock_supported?: false)

      expect { described_class.version }.to raise_error(
        DiscourseVips::Error,
        "Cannot run libvips because Landlock sandboxing is unavailable",
      )
    end
  end

  describe ".generate_letter_avatar" do
    it "renders an opaque 360 by 360 RGB PNG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "avatar.png")
        font_path = File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2")

        described_class.generate_letter_avatar(
          letter: "<",
          background_color: [198, 125, 40],
          font_path:,
          output_path:,
        )

        image = ChunkyPNG::Image.from_file(output_path)
        expect([image.width, image.height]).to eq([360, 360])
        expect(image.pixels.all? { |pixel| ChunkyPNG::Color.a(pixel) == 255 }).to eq(true)
        expect(image[0, 0]).to eq(ChunkyPNG::Color.rgb(198, 125, 40))
        expect(image.pixels.uniq.length).to be > 2
      end
    end
  end

  describe ".dominant_color" do
    it "returns an uppercase RGB hex color" do
      input_path = file_from_fixtures("cropped.png").path

      expect(described_class.dominant_color(input_path:)).to eq("524F40")
    end

    it "accepts a supported image with a nonstandard file extension" do
      Tempfile.create(%w[dominant-color .bin], binmode: true) do |file|
        file.write(File.binread(file_from_fixtures("cropped.png").path))
        file.flush

        expect(described_class.dominant_color(input_path: file.path)).to eq("524F40")
      end
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
    it "rasterizes SVG" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        output_path = File.join(directory, "topic.png")
        svg_path = file_from_fixtures("image.svg").path

        described_class.generate_topic_og_image(svg_path:, output_path:)

        expect(FastImage.type(output_path)).to eq(:png)
      end
    end

    it "rejects raster input" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        expect {
          described_class.generate_topic_og_image(
            svg_path: file_from_fixtures("logo.png").path,
            output_path: File.join(directory, "topic.png"),
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end
  end
end
