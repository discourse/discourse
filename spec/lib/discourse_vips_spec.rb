# frozen_string_literal: true

require "chunky_png"

RSpec.describe DiscourseVips do
  shared_examples "JPEG operation instrumentation" do |method, filename, operation|
    it "records the specific image-processing operation" do
      SiteSetting.instrument_image_processing = true
      input_path = file_from_fixtures(filename).path

      Dir.mktmpdir do |directory|
        events =
          DiscourseEvent.track_events(:image_processing_finished) do
            described_class.public_send(
              method,
              input_path:,
              output_path: File.join(directory, "output.jpg"),
              quality: SiteSetting.image_quality,
              timeout: 20,
            )
          end

        expect(events.first[:params].first.except(:duration_seconds)).to eq(
          operation:,
          success: true,
        )
      end
    end
  end

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
    it "detects animation in a GIF" do
      input_path = file_from_fixtures("tiny_animated.gif").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(true)
    end

    it "detects animation in a WebP" do
      input_path = file_from_fixtures("animated.webp").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(true)
    end

    it "detects animation in an AVIF" do
      input_path = file_from_fixtures("multipage.avif").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(true)
    end

    it "identifies a static GIF" do
      input_path = file_from_fixtures("static.gif").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(false)
    end

    it "identifies a static WebP" do
      input_path = file_from_fixtures("static.webp").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(false)
    end

    it "identifies a static AVIF" do
      input_path = file_from_fixtures("static.avif").path

      expect(described_class.animated?(input_path:, timeout: 5)).to eq(false)
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

  describe ".heif_to_jpeg" do
    include_examples "JPEG operation instrumentation",
                     :heif_to_jpeg,
                     "should_be_jpeg.heic",
                     "upload_heif_to_jpeg"

    shared_examples "HEIF conversion" do |filename|
      it "converts #{filename} to JPEG without changing the source" do
        input_path = file_from_fixtures(filename).path
        original_content = File.binread(input_path)

        Dir.mktmpdir do |directory|
          output_path = File.join(directory, "converted.jpg")

          described_class.heif_to_jpeg(
            input_path:,
            output_path:,
            quality: SiteSetting.image_quality,
            timeout: 20,
          )

          expect(FastImage.type(output_path)).to eq(:jpeg)
          expect(FastImage.size(output_path)).to eq([60, 40])
          expect(File.binread(input_path)).to eq(original_content)
        end
      end
    end

    context "with an opaque 12-bit HEIF" do
      include_examples "HEIF conversion", "heif-color-grid-12bit.heic"
    end

    context "with a transparent 12-bit HEIF" do
      include_examples "HEIF conversion", "heif-color-grid-alpha-12bit.heic"
    end

    it "preserves image dimensions without changing the source" do
      input_path = file_from_fixtures("should_be_jpeg.heic").path
      original_content = File.binread(input_path)

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        described_class.heif_to_jpeg(
          input_path:,
          output_path:,
          quality: SiteSetting.image_quality,
          timeout: 20,
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(FastImage.size(output_path)).to eq([846, 1129])
        expect(File.binread(input_path)).to eq(original_content)
      end
    end

    it "encodes HEIF inputs at the requested quality" do
      input_path = file_from_fixtures("should_be_jpeg.heic").path

      Dir.mktmpdir do |directory|
        lower_quality_path = File.join(directory, "lower-quality.jpg")
        higher_quality_path = File.join(directory, "higher-quality.jpg")

        described_class.heif_to_jpeg(
          input_path:,
          output_path: lower_quality_path,
          quality: 40,
          timeout: 20,
        )
        described_class.heif_to_jpeg(
          input_path:,
          output_path: higher_quality_path,
          quality: 95,
          timeout: 20,
        )

        expect(File.size(lower_quality_path)).to be < File.size(higher_quality_path)
      end
    end

    it "rejects a different image format without changing the source" do
      input_path = file_from_fixtures("logo.png").path
      original_content = File.binread(input_path)

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        expect {
          described_class.heif_to_jpeg(
            input_path:,
            output_path:,
            quality: SiteSetting.image_quality,
            timeout: 20,
          )
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
          described_class.heif_to_jpeg(
            input_path:,
            output_path: input_path,
            quality: SiteSetting.image_quality,
            timeout: 20,
          )
        }.to raise_error(
          DiscourseVips::Error,
          "JPEG conversion requires separate input and output files",
        )

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
            described_class.heif_to_jpeg(
              input_path:,
              output_path:,
              quality: SiteSetting.image_quality,
              timeout: 0.05,
            )
          }.to raise_error(DiscourseVips::OperationTimeout)
        end

        expect(File.exist?(output_path)).to eq(false)
      end
    end
  end

  describe ".svg_dimensions" do
    it "returns explicit SVG dimensions" do
      input_path = file_from_fixtures("image.svg").path

      expect(described_class.svg_dimensions(input_path:, timeout: 5)).to eq([100, 50])
    end

    it "rounds fractional SVG dimensions" do
      input_path = file_from_fixtures("tiny.svg").path

      expect(described_class.svg_dimensions(input_path:, timeout: 5)).to eq([115, 86])
    end

    it "returns large SVG dimensions" do
      input_path = file_from_fixtures("massive.svg").path

      expect(described_class.svg_dimensions(input_path:, timeout: 5)).to eq([11_520, 11_615])
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

    it "rejects a zero-sized SVG with surrounding viewBox whitespace" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" viewBox=" 0 0 120 90 "/>',
          "whitespace-viewbox.svg",
        )

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 5) }.to raise_error(
        DiscourseVips::InvalidImage,
      )
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

    it "rejects an SVG with zero width" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="0" height="60" viewBox="0 0 120 90"/>',
          "zero-width.svg",
        )

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 5) }.to raise_error(
        DiscourseVips::InvalidImage,
      )
    end

    it "rejects an SVG with zero height" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="0" viewBox="0 0 120 90"/>',
          "zero-height.svg",
        )

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 5) }.to raise_error(
        DiscourseVips::InvalidImage,
      )
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

    it "bounds dimensionless SVG filter graphs and keeps the worker available" do
      filter_primitives =
        10_000
          .times
          .map do |index|
            input = index.zero? ? "SourceGraphic" : "blur#{index - 1}"
            %(<feGaussianBlur in="#{input}" result="blur#{index}" stdDeviation="5"/>)
          end
          .join
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs><filter id="dense">#{filter_primitives}</filter></defs>
          <rect width="300" height="100" fill="#ff0000" filter="url(#dense)"/>
        </svg>
      SVG
      file = file_from_contents(svg, "dimensionless-dense-filter.svg")
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { described_class.svg_dimensions(input_path: file.path, timeout: 10) }.to raise_error(
        DiscourseVips::Error,
        "libvips operation failed",
      ) { |error| expect(error).not_to be_a(DiscourseVips::OperationTimeout) }

      elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      expect(elapsed_seconds).to be < 2.5
      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe ".png_to_jpeg" do
    include_examples "JPEG operation instrumentation",
                     :png_to_jpeg,
                     "logo.png",
                     "upload_png_to_jpeg"

    it "flattens transparent PNG pixels onto white" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        described_class.png_to_jpeg(
          input_path: file_from_fixtures("dominant-color-transparent.png").path,
          output_path:,
          quality: SiteSetting.ImageQuality.png_to_jpg_quality,
          timeout: 5,
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(described_class.dominant_color(input_path: output_path, timeout: 5)).to eq("FFFFFF")
      end
    end

    it "rejects non-PNG input" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        expect {
          described_class.png_to_jpeg(
            input_path: file_from_fixtures("logo.jpg").path,
            output_path:,
            quality: SiteSetting.ImageQuality.png_to_jpg_quality,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
        expect(File.exist?(output_path)).to eq(false)
      end
    end
  end

  describe ".recompress_jpeg" do
    include_examples "JPEG operation instrumentation",
                     :recompress_jpeg,
                     "logo.jpg",
                     "upload_jpeg_recompression"

    it "encodes JPEG inputs at the requested quality" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")
        input_path = file_from_fixtures("logo.jpg").path

        described_class.recompress_jpeg(input_path:, output_path:, quality: 40, timeout: 5)

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(FastImage.size(output_path)).to eq(FastImage.size(input_path))
        higher_quality_path = File.join(directory, "higher-quality.jpg")
        described_class.recompress_jpeg(
          input_path:,
          output_path: higher_quality_path,
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
          described_class.recompress_jpeg(
            input_path:,
            output_path: input_path,
            quality: 40,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::Error, /separate input and output/)
        expect(File.binread(input_path)).to eq(original)
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
          output_path = input_path
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

          described_class.auto_orient(input_path:, quality: 95, timeout: 5)

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

    it "preserves the input and removes the temporary output when conversion fails" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "original.jpg")
        original = "invalid JPEG"
        File.binwrite(input_path, original)

        expect { described_class.auto_orient(input_path:, quality: 95, timeout: 5) }.to raise_error(
          DiscourseVips::InvalidImage,
        )
        expect(File.binread(input_path)).to eq(original)
        expect(Dir.children(directory)).to contain_exactly("original.jpg")
      end
    end
  end
end
