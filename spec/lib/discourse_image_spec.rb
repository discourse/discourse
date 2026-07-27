# frozen_string_literal: true

RSpec.describe DiscourseImage do
  let(:fixtures_path) { Rails.root.join("spec/fixtures/images") }

  around do |example|
    Dir.mktmpdir("discourse-image-spec") do |directory|
      @temporary_directory = directory
      example.run
    end
  end

  describe "public API" do
    it "exposes only the approved image operations" do
      methods = described_class.singleton_methods(false)

      expect(methods).to contain_exactly(
        :animated?,
        :calculate_dominant_color,
        :convert,
        :crop,
        :optimize!,
        :orientation,
        :recompress!,
        :resize,
        :size,
        :type,
      )
    end
  end

  describe ".type" do
    it "detects the encoded type from content and rewinds IO" do
      path = fixtures_path.join("png_as.bin")
      file = File.open(path, "rb")

      image_type = described_class.type(file)

      expect(image_type).to eq(:png)
      expect(file.pos).to eq(0)
    ensure
      file&.close
    end

    it "raises a stable error for an unsupported file" do
      path = fixtures_path.join("not_an_image")

      expect { described_class.type(path) }.to raise_error(DiscourseImage::UnsupportedFormatError)
    end
  end

  describe ".size" do
    it "returns raster and SVG dimensions" do
      raster_path = fixtures_path.join("logo.png")
      svg_path = fixtures_path.join("image.svg")

      raster_size = described_class.size(raster_path)
      svg_size = described_class.size(svg_path)

      expect(raster_size).to eq([244, 66])
      expect(svg_size).to eq([100, 50])
    end
  end

  describe ".orientation" do
    it "returns normal for an image without a transformed orientation" do
      path = fixtures_path.join("logo.jpg")

      orientation = described_class.orientation(path)

      expect(orientation).to eq(:normal)
    end
  end

  describe ".animated?" do
    it "distinguishes animated and static images" do
      animated_path = fixtures_path.join("animated.gif")
      static_path = fixtures_path.join("logo.jpg")

      animated = described_class.animated?(animated_path, timeout: 5)
      static = described_class.animated?(static_path)

      expect(animated).to eq(true)
      expect(static).to eq(false)
    end
  end

  describe ".calculate_dominant_color" do
    it "returns an uppercase hexadecimal color" do
      path = fixtures_path.join("logo.jpg")

      color = described_class.calculate_dominant_color(path)

      expect(color).to match(/\A[0-9A-F]{6}\z/)
    end
  end

  describe ".resize" do
    it "preserves aspect ratio for dimension, scale, and pixel limit modes" do
      input = fixtures_path.join("logo.png")
      bounded_output = File.join(@temporary_directory, "bounded.jpg")
      scaled_output = File.join(@temporary_directory, "scaled.jpg")
      limited_output = File.join(@temporary_directory, "limited.jpg")

      described_class.resize(
        input: input,
        output: bounded_output,
        width: 100,
        height: 50,
        allow_upscale: false,
      )
      described_class.resize(input: input, output: scaled_output, scale: 0.5)
      described_class.resize(input: input, output: limited_output, maximum_pixels: 10_000)

      expect(described_class.size(bounded_output)).to eq([100, 27])
      expect(described_class.size(scaled_output)).to eq([122, 33])
      expect(described_class.size(limited_output)).to eq([192, 52])
    end

    it "rejects conflicting sizing modes" do
      input = fixtures_path.join("logo.jpg")
      output = File.join(@temporary_directory, "resized.jpg")

      expect do
        described_class.resize(input: input, output: output, width: 100, scale: 0.5)
      end.to raise_error(ArgumentError, /exactly one sizing mode/)
    end
  end

  describe ".crop" do
    it "writes exact dimensions for center and top positions" do
      input = fixtures_path.join("logo.png")
      center_output = File.join(@temporary_directory, "center.png")
      top_output = File.join(@temporary_directory, "top.png")

      described_class.crop(input: input, output: center_output, width: 100, height: 100)
      described_class.crop(
        input: input,
        output: top_output,
        width: 100,
        height: 100,
        position: :top,
      )

      expect(described_class.size(center_output)).to eq([100, 100])
      expect(described_class.size(top_output)).to eq([100, 100])
    end
  end

  describe ".convert" do
    it "infers the output type from the extension" do
      input = fixtures_path.join("logo.jpg")
      output = File.join(@temporary_directory, "converted.png")

      result = described_class.convert(input: input, output: output)

      expect(result).to eq(true)
      expect(described_class.type(output)).to eq(:png)
      expect(described_class.size(output)).to eq([512, 512])
    end

    it "rasterizes SVG input using its viewport dimensions" do
      input = fixtures_path.join("image.svg")
      output = File.join(@temporary_directory, "converted-svg.png")

      result = described_class.convert(input: input, output: output)

      expect(result).to eq(true)
      expect(described_class.type(output)).to eq(:png)
      expect(described_class.size(output)).to eq([100, 50])
    end

    it "maps command timeouts and preserves an existing output" do
      input = fixtures_path.join("logo.jpg")
      output = File.join(@temporary_directory, "converted.png")
      File.binwrite(output, "existing output")
      status = stub(exitstatus: 124)
      error = Discourse::Utils::CommandError.new("timeout", status: status)
      Discourse::Utils.stubs(:execute_command).raises(error)

      expect do described_class.convert(input: input, output: output) end.to raise_error(
        DiscourseImage::TimeoutError,
      )
      expect(File.binread(output)).to eq("existing output")
    end
  end

  describe ".recompress!" do
    it "recompresses above the ceiling and then returns false above the resulting quality" do
      source = fixtures_path.join("logo.jpg")
      path = File.join(@temporary_directory, "recompressed.jpg")
      Discourse::Utils.execute_command("magick", source.to_s, "-quality", "95", path)

      changed = described_class.recompress!(path, maximum_quality: 80)
      unchanged = described_class.recompress!(path, maximum_quality: 90)

      expect(changed).to eq(true)
      expect(unchanged).to eq(false)
      expect(described_class.size(path)).to eq([512, 512])
    end
  end

  describe ".optimize!" do
    it "replaces an image with a smaller optimized result" do
      source = fixtures_path.join("large_and_unoptimized.png")
      path = File.join(@temporary_directory, "optimized.png")
      FileUtils.cp(source, path)
      original_file_size = File.size(path)
      original_dimensions = described_class.size(path)

      changed = described_class.optimize!(path)

      expect(changed).to eq(true)
      expect(File.size(path)).to be < original_file_size
      expect(described_class.size(path)).to eq(original_dimensions)
    end
  end
end
