# frozen_string_literal: true

require "chunky_png"

RSpec.describe DiscourseVips do
  describe ".downsize" do
    def downsize_png(input_path:, output_path:, geometry:)
      described_class.downsize(
        input_path:,
        output_path:,
        input_format: "png",
        output_format: "png",
        geometry:,
        quality: nil,
        timeout: 20,
      )
    end

    it "applies percentage geometry" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "output.png")
        ChunkyPNG::Image.new(101, 51, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        downsize_png(input_path:, output_path:, geometry: "50%")

        expect(FastImage.size(output_path)).to eq([51, 26])
      end
    end

    it "does not enlarge bounding-box geometry" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "output.png")
        ChunkyPNG::Image.new(51, 101, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        downsize_png(input_path:, output_path:, geometry: "100x100>")

        expect(FastImage.size(output_path)).to eq([50, 100])
      end
    end

    it "applies pixel-area geometry" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "output.png")
        ChunkyPNG::Image.new(244, 66, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        downsize_png(input_path:, output_path:, geometry: "1000@")

        expect(FastImage.size(output_path)).to eq([61, 16])
      end
    end

    it "uses native SVG dimensions while rasterizing to PNG" do
      input_path = file_from_fixtures("tiny.svg").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "svg",
          output_format: "png",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )

        expect(FastImage.size(output_path)).to eq([58, 43])
      end
    end

    it "replaces an input only after successful in-place downsizing" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgba(0, 255, 0, 128)).save(input_path)

        downsize_png(input_path:, output_path: input_path, geometry: "50%")

        image = ChunkyPNG::Image.from_file(input_path)
        expect([image.width, image.height]).to eq([30, 20])
        expect(image[15, 10]).to eq(ChunkyPNG::Color.rgba(0, 255, 0, 128))
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end

    it "preserves an existing destination when decoding fails" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "invalid.png")
        output_path = File.join(directory, "existing.png")
        File.binwrite(input_path, "invalid image")
        File.binwrite(output_path, "original destination")

        expect { downsize_png(input_path:, output_path:, geometry: "50%") }.to raise_error(
          DiscourseVips::InvalidImage,
        )

        expect(File.binread(output_path)).to eq("original destination")
        expect(Dir.children(directory)).to contain_exactly("invalid.png", "existing.png")
      end
    end
  end
end
