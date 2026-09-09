# frozen_string_literal: true

require "chunky_png"
require "vips"

RSpec.describe DiscourseVips do
  describe ".version" do
    it "returns the libvips version" do
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".dominant_color" do
    def dominant_color(filename)
      described_class.dominant_color(input_path: file_from_fixtures(filename).path, timeout: 5)
    end

    it "ignores RGB values in fully transparent pixels" do
      expect(dominant_color("dominant-color-hidden-rgb.png")).to eq("FF0000")
    end

    it "weights partially transparent pixels by their alpha" do
      expect(dominant_color("dominant-color-semitransparent.png")).to eq("AA0055")
    end

    it "returns black for a fully transparent image" do
      expect(dominant_color("dominant-color-transparent.png")).to eq("000000")
    end

    it "preserves low nonzero alpha values in 16-bit images" do
      expect(dominant_color("dominant-color-low-alpha-16bit.png")).to eq("FF0000")
    end

    it "normalizes floating-point grayscale JXL color values" do
      expect(dominant_color("dominant-color-float.jxl")).to eq("808080")
    end
  end

  describe ".animated?" do
    %w[tiny_animated.gif animated.gif animated.webp multipage.avif].each do |filename|
      it "detects animation in #{filename}" do
        input_path = file_from_fixtures(filename).path

        expect(described_class.animated?(input_path:, timeout: 5)).to eq(true)
      end
    end

    %w[static.gif static.webp static.avif].each do |filename|
      it "identifies #{filename} as static" do
        input_path = file_from_fixtures(filename).path

        expect(described_class.animated?(input_path:, timeout: 5)).to eq(false)
      end
    end

    it "rejects an unreadable image" do
      Tempfile.create(%w[unreadable .gif]) do |file|
        file.write("invalid image")
        file.flush

        expect { described_class.animated?(input_path: file.path, timeout: 5) }.to raise_error(
          DiscourseVips::InvalidImage,
        )
      end
    end
  end

  describe ".svg_dimensions" do
    {
      "image.svg" => [100, 50],
      "tiny.svg" => [115, 86],
      "massive.svg" => [11_520, 11_615],
      "zero_sized.svg" => [120, 90],
    }.each do |filename, dimensions|
      it "returns the intrinsic dimensions of #{filename}" do
        result =
          described_class.svg_dimensions(input_path: file_from_fixtures(filename).path, timeout: 5)

        expect(result).to eq(dimensions)
      end
    end

    it "uses the viewBox when the SVG has no explicit dimensions" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 90"/>',
          "viewbox.svg",
        )

      dimensions = described_class.svg_dimensions(input_path: file.path, timeout: 5)

      expect(dimensions).to eq([120, 90])
    end

    it "uses a viewBox with surrounding whitespace for zero-sized SVGs" do
      [" 0 0 120 90", " \t\n0\t0\n120 90\r "].each do |viewbox|
        file =
          file_from_contents(
            %(<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" viewBox="#{viewbox}"/>),
            "whitespace-viewbox.svg",
          )

        dimensions = described_class.svg_dimensions(input_path: file.path, timeout: 5)

        expect(dimensions).to eq([120, 90])
      end
    end

    it "rejects a zero-sized SVG without a viewBox" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0"/>',
          "zero.svg",
        )

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 5) }.to raise_error(
        DiscourseVips::InvalidImage,
      )
    end

    { [0, 60] => [120, 60], [80, 0] => [80, 90] }.each do |dimensions, expected_dimensions|
      it "uses the corresponding viewBox dimension for #{dimensions.inspect}" do
        file =
          file_from_contents(
            %(<svg xmlns="http://www.w3.org/2000/svg" width="#{dimensions[0]}" height="#{dimensions[1]}" viewBox="0 0 120 90"/>),
            "zero-dimension.svg",
          )

        result = described_class.svg_dimensions(input_path: file.path, timeout: 5)

        expect(result).to eq(expected_dimensions)
      end
    end

    it "rejects non-SVG images" do
      expect {
        described_class.svg_dimensions(
          input_path: file_from_fixtures("cropped.png").path,
          timeout: 5,
        )
      }.to raise_error(DiscourseVips::InvalidImage)
    end

    it "rejects malformed SVGs" do
      file = file_from_contents('<svg width="100" height="50">', "invalid.svg")

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 5) }.to raise_error(
        DiscourseVips::InvalidImage,
      )
    end
  end

  describe ".svg_to_png" do
    it "renders transparent pixels against a white background" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="12" height="4">
          <rect width="4" height="4" fill="#ff0000"/>
          <rect x="4" width="4" height="4" fill="#00ff00" fill-opacity="0.5"/>
        </svg>
      SVG
      file = file_from_contents(svg, "transparency.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(input_path: file.path, output_path:, timeout: 5)

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([12, 4])
        expect([png[2, 2], png[10, 2]]).to eq(
          [ChunkyPNG::Color.rgb(255, 0, 0), ChunkyPNG::Color.rgb(255, 255, 255)],
        )
        blended_pixel = png[6, 2]
        expect([ChunkyPNG::Color.r(blended_pixel), ChunkyPNG::Color.b(blended_pixel)]).to all(
          be_within(1).of(128),
        )
        expect([ChunkyPNG::Color.g(blended_pixel), ChunkyPNG::Color.a(blended_pixel)]).to eq(
          [255, 255],
        )
      end
    end

    { "tiny.svg" => [115, 86], "zero_sized.svg" => [120, 90] }.each do |filename, dimensions|
      it "renders #{filename} at its intrinsic dimensions" do
        Dir.mktmpdir do |directory|
          output_path = File.join(directory, "output.png")

          described_class.svg_to_png(
            input_path: file_from_fixtures(filename).path,
            output_path:,
            timeout: 5,
          )

          png = ChunkyPNG::Image.from_file(output_path)
          expect([png.width, png.height]).to eq(dimensions)
        end
      end
    end

    it "rejects malformed SVGs without writing a PNG" do
      file = file_from_contents('<svg width="100" height="50">', "invalid.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(input_path: file.path, output_path:, timeout: 5)
        }.to raise_error(DiscourseVips::InvalidImage)
        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "rejects non-SVG images" do
      Dir.mktmpdir do |directory|
        expect {
          described_class.svg_to_png(
            input_path: file_from_fixtures("cropped.png").path,
            output_path: File.join(directory, "output.png"),
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
      end
    end

    it "preserves the SVG when the output points to the input file" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>'

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "input.svg")
        output_path = File.join(directory, "output.png")
        File.write(input_path, svg)
        File.link(input_path, output_path)

        expect { described_class.svg_to_png(input_path:, output_path:, timeout: 5) }.to raise_error(
          DiscourseVips::Error,
          "SVG input and PNG output must be different files",
        )
        expect(File.read(input_path)).to eq(svg)
      end
    end
  end

  describe ".topic_og_render" do
    it "preserves the rendered size of short title text" do
      Dir.mktmpdir do |directory|
        rendered_titles =
          [false, true].map do |marked_title|
            input_path = File.join(directory, "title-#{marked_title}.svg")
            output_path = File.join(directory, "title-#{marked_title}.png")
            marker = marked_title ? 'class="topic-og-title"' : ""
            File.write(input_path, <<~SVG)
              <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
                <text #{marker} x="80" y="190" font-family="sans-serif" font-size="62" font-weight="700">Hello world</text>
              </svg>
            SVG

            described_class.topic_og_render(input_path:, output_path:, timeout: 5)

            ChunkyPNG::Image.from_file(output_path).crop(80, 100, 1040, 100).pixels
          end

        expect(rendered_titles.first.any? { |pixel| ChunkyPNG::Color.a(pixel).positive? }).to eq(
          true,
        )
        expect(rendered_titles.last).to eq(rendered_titles.first)
      end
    end

    it "renders adjacent image assets on an 8-bit transparent canvas" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "og.svg")
        output_path = File.join(directory, "og.png")
        asset_path = File.join(directory, "logo.png")
        ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color.rgb(255, 0, 0)).save(asset_path)
        File.write(input_path, <<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">
            <image href="#{asset_path}" width="100" height="100"/>
          </svg>
        SVG

        described_class.topic_og_render(input_path:, output_path:, timeout: 5)

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([1200, 630])
        expect(File.binread(output_path).getbyte(24)).to eq(8)
        expect(png[50, 50]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
        expect(ChunkyPNG::Color.a(png[200, 200])).to eq(0)
      end
    end

    it "rejects malformed SVGs" do
      file = file_from_contents('<svg width="1200" height="630">', "invalid.svg")

      Dir.mktmpdir do |directory|
        expect {
          described_class.topic_og_render(
            input_path: file.path,
            output_path: File.join(directory, "output.png"),
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
      end
    end

    it "preserves the SVG when the output points to the input file" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630"/>'

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "input.svg")
        output_path = File.join(directory, "output.png")
        File.write(input_path, svg)
        File.link(input_path, output_path)

        expect {
          described_class.topic_og_render(input_path:, output_path:, timeout: 5)
        }.to raise_error(DiscourseVips::Error, "SVG input and PNG output must be different files")
        expect(File.read(input_path)).to eq(svg)
      end
    end
  end

  describe ".heif_to_jpeg" do
    {
      "heif-color-grid-12bit.heic" => [
        [255, 0, 0],
        [0, 255, 0],
        [0, 0, 255],
        [0, 255, 255],
        [255, 0, 255],
        [255, 255, 0],
      ],
      "heif-color-grid-alpha-12bit.heic" => [
        [255, 255, 255],
        [128, 255, 128],
        [0, 0, 255],
        [0, 255, 255],
        [255, 0, 255],
        [255, 255, 0],
      ],
    }.each do |filename, expected_colors|
      it "preserves the colors of #{filename} when converting to JPEG" do
        input_path = file_from_fixtures(filename).path

        Dir.mktmpdir do |directory|
          output_path = File.join(directory, "converted.jpg")
          png_path = File.join(directory, "converted.png")

          described_class.heif_to_jpeg(input_path:, output_path:, timeout: 20)

          ImageMagick.magick(
            output_path,
            png_path,
            operation: :upload_format_conversion,
            read: [output_path],
            write: [directory],
          )
          image = ChunkyPNG::Image.from_file(png_path)

          expect([image.width, image.height]).to eq([60, 40])
          expected_colors.each_with_index do |expected_rgb, index|
            pixel = image[10 + (index % 3) * 20, 10 + (index / 3) * 20]
            actual_rgb = [
              ChunkyPNG::Color.r(pixel),
              ChunkyPNG::Color.g(pixel),
              ChunkyPNG::Color.b(pixel),
            ]

            expect(actual_rgb).to match(expected_rgb.map { |channel| be_within(5).of(channel) })
          end
        end
      end
    end

    it "preserves image dimensions and its color profile in a nonprogressive JPEG" do
      input_path = file_from_fixtures("should_be_jpeg.heic").path
      original_content = File.binread(input_path)
      original_profile = Vips::Image.heifload(input_path).get("icc-profile-data")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        described_class.heif_to_jpeg(input_path:, output_path:, timeout: 20)

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(FastImage.size(output_path)).to eq([846, 1129])
        expect(File.binread(input_path)).to eq(original_content)
        expect(Vips::Image.jpegload(output_path).get("icc-profile-data")).to eq(original_profile)
        jpeg_metadata =
          ImageMagick.identify(
            "-format",
            "%[interlace] %[profiles]",
            output_path,
            operation: :upload_quality_probe,
            read: [output_path],
          ).split
        expect(jpeg_metadata.first).to eq("None")
        expect(jpeg_metadata.last.split(",")).to include("icc")
      end
    end

    it "rejects a different image format without changing the source" do
      input_path = file_from_fixtures("logo.png").path
      original_content = File.binread(input_path)

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        expect {
          described_class.heif_to_jpeg(input_path:, output_path:, timeout: 20)
        }.to raise_error(DiscourseVips::InvalidImage)

        expect(File.binread(input_path)).to eq(original_content)
        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "rejects overwriting the source image" do
      original_content = File.binread(file_from_fixtures("should_be_jpeg.heic").path)

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.heic")
        File.binwrite(input_path, original_content)

        expect {
          described_class.heif_to_jpeg(input_path:, output_path: input_path, timeout: 20)
        }.to raise_error(DiscourseVips::Error, "input and output must be different files")

        expect(File.binread(input_path)).to eq(original_content)
      end
    end

    it "stops when reading the source exceeds the timeout" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "blocked.heic")
        output_path = File.join(directory, "converted.jpg")
        File.mkfifo(input_path)

        File.open(input_path, File::RDWR) do
          expect {
            described_class.heif_to_jpeg(input_path:, output_path:, timeout: 0.05)
          }.to raise_error(DiscourseVips::OperationTimeout)
        end

        expect(File.exist?(output_path)).to eq(false)
      end
    end
  end

  describe "worker lifecycle" do
    it "recovers after the worker exits unexpectedly" do
      described_class.version
      worker_pid =
        Integer(
          IO.popen(["pgrep", "-P", Process.pid.to_s, "-f", "discourse vips worker"]) do |process|
            process.read
          end,
          10,
        )

      Process.kill("KILL", worker_pid)
      Process.waitpid(worker_pid)

      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "recovers after an operation times out" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "blocked.png")
        File.mkfifo(input_path)

        File.open(input_path, File::RDWR) do
          expect { described_class.dominant_color(input_path:, timeout: 0.05) }.to raise_error(
            DiscourseVips::OperationTimeout,
            "libvips operation timed out",
          )
        end
      end

      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "times out when the worker sends an incomplete response" do
      Dir.mktmpdir do |directory|
        socket_path = File.join(directory, "socket")
        server = UNIXServer.new(socket_path)
        server_thread =
          Thread.new do
            connection = server.accept
            connection.read
            connection.write("\x81")
            sleep 3
          ensure
            connection&.close
          end

        DiscourseVips::Client.stubs(:worker_socket_path).returns(socket_path)

        expect {
          described_class.dominant_color(input_path: "unused", timeout: 0.01)
        }.to raise_error(DiscourseVips::WorkerUnavailable, "libvips worker did not respond")
      ensure
        server&.close
        server_thread&.kill
        server_thread&.join
      end
    end
  end

  it "records image-processing instrumentation" do
    SiteSetting.instrument_image_processing = true
    input_path = file_from_fixtures("cropped.png").path

    events =
      DiscourseEvent.track_events(:image_processing_finished) do
        described_class.dominant_color(input_path:, timeout: 5)
      end

    expect(events.first[:params].first.except(:duration_seconds)).to eq(
      operation: "upload_dominant_color",
      success: true,
    )
  end
end
