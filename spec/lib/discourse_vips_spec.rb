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

  describe ".ico_to_png" do
    it "rejects a truncated bitmap without creating an output" do
      input_path = file_from_fixtures("ico-truncated-bitmap.ico").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.png")

        expect {
          described_class.ico_to_png(input_path:, output_path:, timeout: 20)
        }.to raise_error(DiscourseVips::InvalidImage)

        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "decodes a 16-bit RGB555 bitmap" do
      input_path = file_from_fixtures("ico-bmp-16bit.ico").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.png")

        described_class.ico_to_png(input_path:, output_path:, timeout: 20)
        image = ChunkyPNG::Image.from_file(output_path)

        expect([image.width, image.height]).to eq([60, 40])
        expect(image[10, 10]).to eq(ChunkyPNG::Color.rgba(255, 0, 0, 255))
        expect(image[30, 10]).to eq(ChunkyPNG::Color.rgba(0, 255, 0, 255))
        expect(image[50, 10]).to eq(ChunkyPNG::Color.rgba(0, 0, 255, 255))
      end
    end

    it "preserves the bitmap colors without modifying the source" do
      input_path = file_from_fixtures("smallest.ico").path
      original_content = File.binread(input_path)

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.png")

        described_class.ico_to_png(input_path:, output_path:, timeout: 20)
        image = ChunkyPNG::Image.from_file(output_path)

        expect([image.width, image.height]).to eq([1, 1])
        expect(image[0, 0]).to eq(ChunkyPNG::Color.rgba(255, 0, 0, 255))
        expect(File.binread(input_path)).to eq(original_content)
      end
    end

    it "rejects overwriting the source image" do
      original_content = File.binread(file_from_fixtures("smallest.ico").path)

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.ico")
        File.binwrite(input_path, original_content)

        expect {
          described_class.ico_to_png(input_path:, output_path: input_path, timeout: 20)
        }.to raise_error(DiscourseVips::Error, "input and output must be different files")

        expect(File.binread(input_path)).to eq(original_content)
      end
    end

    it "rejects a truncated ICO directory without creating an output" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "truncated.ico")
        output_path = File.join(directory, "converted.png")
        File.binwrite(input_path, [0, 1, 1].pack("v3"))

        expect {
          described_class.ico_to_png(input_path:, output_path:, timeout: 20)
        }.to raise_error(DiscourseVips::InvalidImage, "invalid ICO directory")

        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "rejects an image offset outside the input without creating an output" do
      content = File.binread(file_from_fixtures("smallest.ico").path)
      content[18, 4] = [content.bytesize + 1].pack("V")

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "invalid-offset.ico")
        output_path = File.join(directory, "converted.png")
        File.binwrite(input_path, content)

        expect {
          described_class.ico_to_png(input_path:, output_path:, timeout: 20)
        }.to raise_error(DiscourseVips::InvalidImage, "invalid ICO image offset")

        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "stops when reading the source exceeds the timeout" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "blocked.ico")
        output_path = File.join(directory, "converted.png")
        File.mkfifo(input_path)

        File.open(input_path, File::RDWR) do
          expect {
            described_class.ico_to_png(input_path:, output_path:, timeout: 0.05)
          }.to raise_error(DiscourseVips::OperationTimeout)
        end

        expect(File.exist?(output_path)).to eq(false)
      end
    end
  end

  describe ".convert_to_jpeg" do
    it "flattens transparent PNG pixels onto white" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        described_class.convert_to_jpeg(
          input_path: file_from_fixtures("dominant-color-transparent.png").path,
          output_path:,
          input_format: "png",
          quality: 92,
          timeout: 5,
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(described_class.dominant_color(input_path: output_path, timeout: 5)).to eq("FFFFFF")
      end
    end

    it "encodes JPEG inputs at the requested quality" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")
        input_path = file_from_fixtures("logo.jpg").path

        described_class.convert_to_jpeg(
          input_path:,
          output_path:,
          input_format: "jpeg",
          quality: 40,
          timeout: 5,
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(FastImage.size(output_path)).to eq(FastImage.size(input_path))
        higher_quality_path = File.join(directory, "higher-quality.jpg")
        described_class.convert_to_jpeg(
          input_path:,
          output_path: higher_quality_path,
          input_format: "jpeg",
          quality: 95,
          timeout: 5,
        )
        expect(File.size(output_path)).to be < File.size(higher_quality_path)
      end
    end

    it "preserves the input when the output refers to the same file" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "original.jpg")
        FileUtils.cp(file_from_fixtures("logo.jpg").path, input_path)
        original = File.binread(input_path)

        expect {
          described_class.convert_to_jpeg(
            input_path:,
            output_path: input_path,
            input_format: "jpeg",
            quality: 40,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::Error, /separate input and output/)
        expect(File.binread(input_path)).to eq(original)
      end
    end

    it "rejects input that does not match its declared PNG format" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        expect {
          described_class.convert_to_jpeg(
            input_path: file_from_fixtures("logo.jpg").path,
            output_path:,
            input_format: "png",
            quality: 92,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
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

  describe ".auto_orient" do
    %w[
      TopLeft
      TopRight
      BottomRight
      BottomLeft
      LeftTop
      RightTop
      RightBottom
      LeftBottom
    ].each_with_index do |orientation, index|
      it "normalizes #{orientation} JPEG pixels and orientation metadata" do
        Dir.mktmpdir do |directory|
          input_path = File.join(directory, "oriented.jpg")
          output_path = File.join(directory, "upright.jpg")
          expected_path = File.join(directory, "expected.png")
          actual_path = File.join(directory, "actual.png")
          fixture = file_from_fixtures("exif_orientation.jpg").path
          profile = Rails.root.join("vendor/data/RT_sRGB.icm").to_s
          ImageMagick.magick(
            fixture,
            "-resize",
            "80x48!",
            "-fill",
            "red",
            "-draw",
            "rectangle 0,0 39,23",
            "-fill",
            "green",
            "-draw",
            "rectangle 40,0 79,23",
            "-fill",
            "blue",
            "-draw",
            "rectangle 0,24 39,47",
            "-fill",
            "white",
            "-draw",
            "rectangle 40,24 79,47",
            "+profile",
            "*",
            "-quality",
            "95",
            "-interlace",
            index.even? ? "Plane" : "None",
            input_path,
            operation: :upload_auto_orient,
            read: [fixture, profile],
            write: [directory],
          )
          orientation_tag = [0x0112, 3, 1, index + 1].pack("vvVV")
          exif = "Exif\0\0II".b + [42, 8, 1].pack("vVv") + orientation_tag + [0].pack("V")
          icc = "ICC_PROFILE\0\x01\x01".b + File.binread(profile)
          jpeg = File.binread(input_path)
          metadata = "\xff\xe1".b + [exif.bytesize + 2].pack("n") + exif
          metadata << "\xff\xe2".b << [icc.bytesize + 2].pack("n") << icc
          File.binwrite(input_path, jpeg.byteslice(0, 2) + metadata + jpeg.byteslice(2..))
          expect(FastImage.new(input_path).orientation).to eq(index + 1)
          ImageMagick.magick(
            input_path,
            "-auto-orient",
            expected_path,
            operation: :upload_auto_orient,
            read: [input_path],
            write: [directory],
          )

          described_class.auto_orient(input_path:, output_path:, source_quality: 95, timeout: 5)

          image_info = FastImage.new(output_path)
          expect(image_info.type).to eq(:jpeg)
          expect(image_info.size).to eq(FastImage.size(expected_path))
          expect(
            ImageMagick.identify(
              "-format",
              "%[interlace]",
              output_path,
              operation: :upload_auto_orient,
              read: [output_path],
            ),
          ).to eq("None")
          expect(image_info.orientation).to be_nil.or eq(1)
          ImageMagick.magick(
            output_path,
            actual_path,
            operation: :upload_auto_orient,
            read: [output_path],
            write: [directory],
          )
          expected = ChunkyPNG::Image.from_file(expected_path)
          actual = ChunkyPNG::Image.from_file(actual_path)
          [0.25, 0.75].product([0.25, 0.75])
            .each do |horizontal, vertical|
              column = (actual.width * horizontal).to_i
              row = (actual.height * vertical).to_i
              %i[r g b].each do |channel|
                difference =
                  ChunkyPNG::Color.public_send(channel, actual[column, row]) -
                    ChunkyPNG::Color.public_send(channel, expected[column, row])
                expect(difference.abs).to be < 15
              end
            end
          expect(
            ImageMagick.identify(
              "-format",
              "%[profiles]",
              output_path,
              operation: :upload_auto_orient,
              read: [output_path],
            ),
          ).to include("icc")
        end
      end
    end

    it "preserves the input when asked to overwrite it" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "original.jpg")
        FileUtils.cp(file_from_fixtures("exif_orientation.jpg").path, input_path)
        original = File.binread(input_path)

        expect {
          described_class.auto_orient(
            input_path:,
            output_path: input_path,
            source_quality: 95,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::Error, /separate input and output/)
        expect(File.binread(input_path)).to eq(original)
      end
    end
  end

  describe ".crop" do
    it "rasterizes SVG input over the existing white background" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.svg")
        output_path = File.join(directory, "output.png")
        sources = [
          File.read(Rails.root.join("spec/fixtures/images/image.svg")),
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="red" opacity="0.5"/></svg>',
          '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="blue"/><rect width="100" height="50" fill="red" opacity="0.5"/></svg>',
        ]

        sources.each_with_index do |contents, index|
          File.write(input_path, contents)
          [false, true].each do |strip_metadata|
            described_class.crop(
              input_path:,
              output_path:,
              input_format: "svg",
              output_format: "png",
              width: 30,
              height: 20,
              strip_metadata:,
              quality: nil,
              timeout: 20,
            )

            image = ChunkyPNG::Image.from_file(output_path)
            expect([image.width, image.height]).to eq([30, 20])
            expect(File.read(input_path)).to eq(contents)
            expect(image.pixels.all? { |pixel| ChunkyPNG::Color.a(pixel) == 255 }).to eq(true)
            pixel = image[image.width / 2, image.height / 2]
            case index
            when 0
              expect(image.pixels).to all(eq(ChunkyPNG::Color::WHITE))
            when 1
              expect(ChunkyPNG::Color.r(pixel)).to eq(255)
              expect(ChunkyPNG::Color.g(pixel)).to be_between(126, 128)
              expect(ChunkyPNG::Color.b(pixel)).to be_between(126, 128)
            when 2
              expect(ChunkyPNG::Color.r(pixel)).to be_between(127, 129)
              expect(ChunkyPNG::Color.g(pixel)).to eq(0)
              expect(ChunkyPNG::Color.b(pixel)).to be_between(126, 128)
            end
          end
        end
      end
    end

    it "crops from the top and horizontal center" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        source = ChunkyPNG::Image.new(6, 4, ChunkyPNG::Color.rgb(0, 0, 255))
        source.rect(0, 0, 5, 1, ChunkyPNG::Color.rgb(255, 0, 0), ChunkyPNG::Color.rgb(255, 0, 0))
        source.rect(2, 0, 3, 1, ChunkyPNG::Color.rgb(0, 255, 0), ChunkyPNG::Color.rgb(0, 255, 0))
        source.save(input_path)
        output_path = File.join(directory, "cropped.png")

        described_class.crop(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "png",
          width: 2,
          height: 4,
          quality: nil,
          strip_metadata: false,
          timeout: 20,
        )
        image = ChunkyPNG::Image.from_file(output_path)

        expect([image.width, image.height]).to eq([2, 4])
        expect(image[0, 0]).to eq(ChunkyPNG::Color.rgb(0, 255, 0))
        expect(image[1, 3]).to eq(ChunkyPNG::Color.rgb(0, 0, 255))

        described_class.crop(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "png",
          width: 6,
          height: 2,
          quality: nil,
          strip_metadata: false,
          timeout: 20,
        )
        north_image = ChunkyPNG::Image.from_file(output_path)

        expect([north_image.width, north_image.height]).to eq([6, 2])
        expect(north_image[0, 1]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
      end
    end

    it "keeps the extra column on the right when centering an odd crop remainder" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        red = ChunkyPNG::Color.rgb(255, 0, 0)
        source = ChunkyPNG::Image.new(7, 5, ChunkyPNG::Color.rgb(0, 255, 0))
        source.rect(0, 0, 1, 4, red, red)
        source.save(input_path)
        output_path = File.join(directory, "cropped.png")

        [false, true].each do |strip_metadata|
          [4, 6].each do |width|
            described_class.crop(
              input_path:,
              output_path:,
              input_format: "png",
              output_format: "png",
              width:,
              height: 5,
              quality: nil,
              strip_metadata:,
              timeout: 20,
            )
            image = ChunkyPNG::Image.from_file(output_path)

            expect([image.width, image.height]).to eq([width, 5])
            expect(image[width == 4 ? 0 : 1, 2]).to eq(red)
          end
        end
      end
    end

    it "keeps pixel edges centered when enlarging the crop" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        source = ChunkyPNG::Image.new(40, 40, ChunkyPNG::Color.rgb(255, 255, 255))
        black = ChunkyPNG::Color.rgb(0, 0, 0)
        source.rect(20, 20, 39, 39, black, black)
        source.save(input_path)
        output_path = File.join(directory, "cropped.png")

        [false, true].each do |strip_metadata|
          described_class.crop(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            width: 50,
            height: 50,
            quality: nil,
            strip_metadata:,
            timeout: 20,
          )
          image = ChunkyPNG::Image.from_file(output_path)

          expect([image.width, image.height]).to eq([50, 50])
          expect(ChunkyPNG::Color.r(image[24, 24])).to be > 220
          expect(ChunkyPNG::Color.r(image[25, 25])).to be < 60
        end
      end
    end

    it "preserves translucent pixels while enlarging an image to cover the crop" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        color = ChunkyPNG::Color.rgba(255, 0, 0, 128)
        ChunkyPNG::Image.new(3, 2, color).save(input_path)
        output_path = File.join(directory, "cropped.png")

        described_class.crop(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "png",
          width: 13,
          height: 17,
          quality: nil,
          strip_metadata: true,
          timeout: 20,
        )
        image = ChunkyPNG::Image.from_file(output_path)

        expect([image.width, image.height]).to eq([13, 17])
        expect(image.pixels).to all(eq(color))
      end
    end

    it "retains the source profile while stripping other metadata when requested" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        profile = Rails.root.join("vendor/data/RT_sRGB.icm").to_s
        source = Vips::Image.jpegload(file_from_fixtures("exif_orientation.jpg").path)
        source.pngsave(input_path, profile:)
        expect(Vips::Image.pngload(input_path).get_typeof("exif-data")).to be_positive

        [false, true].each do |strip_metadata|
          output_path = File.join(directory, "cropped-#{strip_metadata}.png")

          described_class.crop(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            width: 3,
            height: 2,
            quality: nil,
            strip_metadata:,
            timeout: 20,
          )
          image = Vips::Image.pngload(output_path)

          expect(image.get("icc-profile-data")).to eq(File.binread(profile))
          if strip_metadata
            expect(image.get_typeof("exif-data")).to eq(0)
          else
            expect(image.get_typeof("exif-data")).to be_positive
          end
        end
      end
    end

    it "retains GIF color profiles and thresholds half-transparent pixels after cropping" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        profile = Rails.root.join("vendor/data/RT_sRGB.icm").to_s
        source =
          Vips::Image
            .black(6, 4)
            .new_from_image([255, 0, 0, 128])
            .cast(:uchar)
            .copy(interpretation: :srgb)
        source.pngsave(input_path, profile:)

        [false, true].each do |strip_metadata|
          output_path = File.join(directory, "cropped-#{strip_metadata}.gif")

          described_class.crop(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "gif",
            width: 3,
            height: 2,
            quality: nil,
            strip_metadata:,
            timeout: 20,
          )
          image = Vips::Image.gifload(output_path)
          image = image.addalpha if !image.has_alpha?

          expect(image.getpoint(1, 1)).to eq([255, 0, 0, 255])
          expect(
            ImageMagick
              .identify(
                "-format",
                "%[profiles]",
                output_path,
                operation: :optimized_image_crop,
                read: [output_path],
                timeout: 20,
              )
              .strip
              .split(","),
          ).to include("icc")
        end
      end
    end

    it "supports cropping a file in place with an explicit format" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.bin")
        ChunkyPNG::Image.new(6, 4, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        described_class.crop(
          input_path:,
          output_path: input_path,
          input_format: "png",
          output_format: "png",
          width: 3,
          height: 2,
          quality: nil,
          strip_metadata: false,
          timeout: 20,
        )
        image = ChunkyPNG::Image.from_file(input_path)

        expect([image.width, image.height]).to eq([3, 2])
        expect(Dir.children(directory)).to eq(["source.bin"])
      end
    end

    it "preserves an existing destination after invalid crop dimensions" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        ChunkyPNG::Image.new(6, 4, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
        original_content = File.binread(input_path)

        expect {
          described_class.crop(
            input_path:,
            output_path: input_path,
            input_format: "png",
            output_format: "png",
            width: 0,
            height: 2,
            quality: nil,
            strip_metadata: false,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "invalid crop dimensions")

        expect(File.binread(input_path)).to eq(original_content)
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end

    it "requires an explicit quality for JPEG output" do
      Dir.mktmpdir do |directory|
        input_path = file_from_fixtures("logo.png").path
        output_path = File.join(directory, "cropped.jpg")

        expect {
          described_class.crop(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "jpeg",
            width: 10,
            height: 10,
            quality: nil,
            strip_metadata: false,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "encoder quality is required")

        expect(File.exist?(output_path)).to eq(false)
        expect(Dir.children(directory)).to eq([])
      end
    end
  end
end
