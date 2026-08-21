# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns the helper and libvips version" do
      expect(described_class.version).to match(/\A1-8\.\d+\.\d+\z/)
    end

    it "runs the helper with the default sandbox limits" do
      Discourse::SafeExec
        .expects(:capture)
        .with do |*command, **options|
          response_path = command[command.index("--response") + 1]
          File.write(response_path, JSON.generate(ok: true, value: "8.18.4"))

          command.first(3) == %w[nice -n 10] &&
            File.basename(command[3]) == "discourse_vips_helper" && command[4] == "version" &&
            options[:timeout] == 5 && options[:seccomp_deny_network] &&
            options[:execute].include?(command[3]) &&
            options[:rlimits] ==
              {
                cpu_seconds: 5,
                memory_bytes: 4 * 1024 * 1024 * 1024,
                file_size_bytes: 10 * 1024 * 1024 * 1024,
                open_files: 1024,
              }
        end
        .returns("")

      expect(described_class.version).to eq("1-8.18.4")
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

    it "matches the original text, gravity, and flatten pipeline" do
      Dir.mktmpdir("discourse-vips-spec") do |directory|
        font_path =
          if RUBY_PLATFORM.match?(/darwin/)
            nil
          else
            File.join(DiscourseFonts.path_for_fonts, "NotoSans-Regular.woff2")
          end
        font_family = font_path ? "Noto Sans" : "Helvetica"
        font_arguments = ["--font", "#{font_family} 280"]
        font_arguments.unshift("--fontfile", font_path) if font_path
        markup = '<span foreground="#ffffff" alpha="80%">A</span>'
        glyph_path = File.join(directory, "glyph.png")
        canvas_path = File.join(directory, "canvas.png")
        original_path = File.join(directory, "original.png")
        helper_path = File.join(directory, "helper.png")

        Vips.run(
          "text",
          glyph_path,
          markup,
          *font_arguments,
          "--rgba",
          read: [font_path].compact,
          write: [directory],
        )
        Vips.run(
          "gravity",
          glyph_path,
          canvas_path,
          "centre",
          "360",
          "360",
          "--extend",
          "background",
          "--background",
          "198 125 40 255",
          read: [glyph_path],
          write: [directory],
        )
        Vips.run(
          "flatten",
          canvas_path,
          original_path,
          "--background",
          "198 125 40",
          read: [canvas_path],
          write: [directory],
        )
        described_class.generate_letter_avatar(
          letter: "A",
          background_color: [198, 125, 40],
          font_path:,
          output_path: helper_path,
        )

        expect(File.binread(helper_path)).to eq(File.binread(original_path))
      end
    end
  end

  describe ".dominant_color" do
    it "matches the existing one-pixel libvips result" do
      input_path = file_from_fixtures("cropped.png").path

      expect(described_class.dominant_color(input_path:)).to eq("3A3730")
    end

    it "selects a supported loader from the content instead of the extension" do
      Tempfile.create(%w[dominant-color .bin], binmode: true) do |file|
        file.write(File.binread(file_from_fixtures("cropped.png").path))
        file.flush

        expect(described_class.dominant_color(input_path: file.path)).to eq("3A3730")
      end
    end

    it "does not use the SVG loader when the input is declared as PNG" do
      input_path = file_from_fixtures("image.svg").path
      FastImage.stubs(:type).with(input_path).returns(:png)

      expect { described_class.dominant_color(input_path:) }.to raise_error(DiscourseVips::Error)
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
