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
              read: [input_path],
              write: [File.dirname(File.join(directory, "output.jpg"))],
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
            read: [input_path],
            write: [File.dirname(output_path)],
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
          read: [input_path],
          write: [File.dirname(output_path)],
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
          read: [input_path],
          write: [File.dirname(lower_quality_path)],
        )
        described_class.heif_to_jpeg(
          input_path:,
          output_path: higher_quality_path,
          quality: 95,
          timeout: 20,
          read: [input_path],
          write: [File.dirname(higher_quality_path)],
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
            read: [input_path],
            write: [File.dirname(output_path)],
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
            read: [input_path],
            write: [File.dirname(input_path)],
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
              read: [input_path],
              write: [File.dirname(output_path)],
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

        input_path = file_from_fixtures("dominant-color-transparent.png").path

        described_class.png_to_jpeg(
          input_path:,
          output_path:,
          quality: SiteSetting.ImageQuality.png_to_jpg_quality,
          timeout: 5,
          read: [input_path],
          write: [File.dirname(output_path)],
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(described_class.dominant_color(input_path: output_path, timeout: 5)).to eq("FFFFFF")
      end
    end

    it "rejects non-PNG input" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")

        input_path = file_from_fixtures("logo.jpg").path

        expect {
          described_class.png_to_jpeg(
            input_path:,
            output_path:,
            quality: SiteSetting.ImageQuality.png_to_jpg_quality,
            timeout: 5,
            read: [input_path],
            write: [File.dirname(output_path)],
          )
        }.to raise_error(DiscourseVips::InvalidImage)
        expect(File.exist?(output_path)).to eq(false)
      end
    end
  end

  describe ".reencode_jpeg" do
    include_examples "JPEG operation instrumentation",
                     :reencode_jpeg,
                     "logo.jpg",
                     "upload_jpeg_reencoding"

    it "encodes JPEG inputs at the requested quality" do
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "converted.jpg")
        input_path = file_from_fixtures("logo.jpg").path

        described_class.reencode_jpeg(
          input_path:,
          output_path:,
          quality: 40,
          timeout: 5,
          read: [input_path],
          write: [File.dirname(output_path)],
        )

        expect(FastImage.type(output_path)).to eq(:jpeg)
        expect(FastImage.size(output_path)).to eq(FastImage.size(input_path))
        higher_quality_path = File.join(directory, "higher-quality.jpg")
        described_class.reencode_jpeg(
          input_path:,
          output_path: higher_quality_path,
          quality: 95,
          timeout: 5,
          read: [input_path],
          write: [File.dirname(higher_quality_path)],
        )
        expect(File.size(output_path)).to be < File.size(higher_quality_path)
      end
    end

    context "when replacing the original JPEG" do
      it "leaves the original JPEG unchanged when reencoding fails" do
        Dir.mktmpdir do |directory|
          input_path = File.join(directory, "original.jpg")
          original = "invalid JPEG"
          File.binwrite(input_path, original)

          expect {
            described_class.reencode_jpeg(
              input_path:,
              output_path: input_path,
              quality: 95,
              timeout: 5,
              read: [input_path],
              write: [input_path],
            )
          }.to raise_error(DiscourseVips::InvalidImage)
          expect(File.binread(input_path)).to eq(original)
          expect(Dir.children(directory)).to contain_exactly("original.jpg")
        end
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

  describe ".svg_to_png" do
    it "renders referenced assets from a caller-permitted directory" do
      Dir.mktmpdir do |directory|
        allowed_path = File.join(directory, "allowed.png")
        ChunkyPNG::Image.new(4, 4, ChunkyPNG::Color.rgb(255, 0, 0)).save(allowed_path)
        input_path = File.join(directory, "input.svg")
        output_directory = File.join(directory, "output")
        Dir.mkdir(output_directory)
        output_path = File.join(output_directory, "output.png")
        File.write(input_path, <<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40">
            <image href="allowed.png" width="40" height="40"/>
          </svg>
        SVG

        described_class.svg_to_png(
          input_path:,
          output_path:,
          read: [directory],
          write: [output_directory],
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect(png[20, 20]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
      end
    end

    it "renders permitted file assets without including unpermitted file assets" do
      skip "Landlock is not supported" if !Discourse::SafeExec.landlock_supported?

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "input.svg")
        allowed_path = File.join(directory, "allowed.png")
        private_path = File.join(directory, "private.png")
        output_path = File.join(directory, "output.png")
        ChunkyPNG::Image.new(4, 4, ChunkyPNG::Color.rgb(255, 0, 0)).save(allowed_path)
        ChunkyPNG::Image.new(4, 4, ChunkyPNG::Color.rgb(0, 255, 0)).save(private_path)
        File.write(output_path, "")
        File.write(input_path, <<~SVG)
          <svg xmlns="http://www.w3.org/2000/svg" width="80" height="40">
            <image href="allowed.png" width="40" height="40"/>
            <image href="private.png" x="40" width="40" height="40"/>
          </svg>
        SVG

        described_class.svg_to_png(
          input_path:,
          output_path:,
          read: [input_path, allowed_path],
          write: [output_path],
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png[20, 20], png[60, 20]]).to eq(
          [ChunkyPNG::Color.rgb(255, 0, 0), ChunkyPNG::Color.rgb(255, 255, 255)],
        )
      end
    end

    it "raises an error when reading the input is not permitted" do
      skip "Landlock is not supported" if !Discourse::SafeExec.landlock_supported?

      file = file_from_fixtures("tiny.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            read: [],
            write: [directory],
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end

    it "renders transparent areas against a white background" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="12" height="4">
          <rect width="4" height="4" fill="#ff0000"/>
        </svg>
      SVG
      file = file_from_contents(svg, "transparency.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(
          input_path: file.path,
          output_path:,
          read: [file.path],
          write: [directory],
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png[2, 2], png[10, 2]]).to eq(
          [ChunkyPNG::Color.rgb(255, 0, 0), ChunkyPNG::Color.rgb(255, 255, 255)],
        )
      end
    end

    it "raises an error for malformed SVG input" do
      file = file_from_contents('<svg width="100" height="50">', "invalid.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            read: [file.path],
            write: [directory],
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end

    it "raises an error when input and output refer to the same file" do
      svg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>'

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "input.svg")
        output_path = File.join(directory, "output.png")
        File.write(input_path, svg)
        File.link(input_path, output_path)

        expect {
          described_class.svg_to_png(
            input_path:,
            output_path:,
            read: [input_path],
            write: [directory],
          )
        }.to raise_error(DiscourseVips::Error, "SVG input and PNG output must be different files")
      end
    end

    it "raises an error when SVG input exceeds the size limit" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="300" height="100">
          #{" " * 3.megabytes}
        </svg>
      SVG
      file = file_from_contents(svg, "oversized.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            read: [file.path],
            write: [directory],
          )
        }.to raise_error(DiscourseVips::Error, /SVG exceeds/)
      end
    end

    it "writes a PNG at the original SVG dimensions" do
      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="200"><rect width="600" height="200" fill="#ff0000"/></svg>',
          "large.svg",
        )

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(
          input_path: file.path,
          output_path:,
          read: [file.path],
          write: [directory],
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([600, 200])
        expect(png[png.width / 2, png.height / 2]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
      end
    end

    it "raises an error when writing the output is not permitted" do
      skip "Landlock is not supported" if !Discourse::SafeExec.landlock_supported?

      file =
        file_from_contents(
          '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="20"/>',
          "input.svg",
        )

      Dir.mktmpdir do |directory|
        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path: File.join(directory, "output.png"),
            read: [file.path],
            write: [],
          )
        }.to raise_error(DiscourseVips::Error)
      end
    end
  end

  describe ".thumbnail" do
    let(:directory) { Dir.mktmpdir }
    let(:input_path) { File.join(directory, "source.jpg") }
    let(:output_path) { File.join(directory, "output.png") }

    before { FileUtils.cp(file_from_fixtures("logo.png").path, input_path) }

    after { FileUtils.remove_entry(directory) }

    it "resizes an image using its contents instead of its input extension" do
      described_class.thumbnail(
        input_path: input_path,
        output_path: output_path,
        width: 100,
        height: 50,
        crop: :centre,
        sharpen: true,
        timeout: 10,
        operation: :optimized_image_resize,
        read: [input_path],
        write: [directory],
      )

      expect(FastImage.size(output_path)).to eq([100, 50])
      expect(FastImage.type(output_path)).to eq(:png)
    end

    it "uses format hints to write PNG data to a .bin output path" do
      destination_path = File.join(directory, "output.bin")

      described_class.thumbnail(
        input_path: input_path,
        output_path: destination_path,
        input_format: "png",
        output_format: "png",
        width: 100,
        height: 50,
        crop: :centre,
        timeout: 10,
        operation: :optimized_image_resize,
        read: [input_path],
        write: [directory],
      )

      expect(FastImage.size(destination_path)).to eq([100, 50])
      expect(FastImage.type(destination_path)).to eq(:png)
    end

    it "rejects PNG data when the input format hint is JPEG" do
      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: output_path,
          input_format: "jpg",
          width: 100,
          height: 50,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::InvalidImage)
    end

    it "rejects an input format outside the raster loader allowlist" do
      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: output_path,
          input_format: "svg",
          width: 100,
          height: 50,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error, "unsupported input format")
    end

    it "rejects unsupported output extensions" do
      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: File.join(directory, "output.svg"),
          width: 100,
          height: 50,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error)
    end

    it "reports a quality option unsupported by the output encoder as an operation error" do
      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: File.join(directory, "output.gif"),
          width: 100,
          height: 50,
          quality: 75,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error)
    end

    it "reports invalid thumbnail options as an operation error" do
      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: output_path,
          width: 100,
          height: 50,
          size: :invalid,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(
        DiscourseVips::Error,
        "ruby-vips: enum 'VipsSize' has no member 'invalid', should be one of: both, up, down, force\n",
      )
    end

    it "preserves the destination and removes temporary files after a decode error" do
      File.binwrite(input_path, "invalid image")
      File.binwrite(output_path, "existing destination")

      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: output_path,
          width: 100,
          height: 50,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::InvalidImage)

      expect(File.binread(output_path)).to eq("existing destination")
      expect(Dir.children(directory)).to contain_exactly("source.jpg", "output.png")
    end

    it "rejects an SVG disguised as a PNG" do
      FileUtils.cp(file_from_fixtures("svg.png").path, input_path)

      expect {
        described_class.thumbnail(
          input_path: input_path,
          output_path: output_path,
          width: 100,
          height: 50,
          timeout: 10,
          operation: :optimized_image_resize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::InvalidImage)
    end

    it "scales an image by the requested factor" do
      described_class.thumbnail(
        input_path:,
        output_path:,
        scale: 0.5,
        sharpen: true,
        timeout: 20,
        operation: :optimized_image_downsize,
        read: [input_path],
        write: [directory],
      )

      expect(FastImage.size(output_path)).to eq([122, 33])
      expect(FastImage.type(output_path)).to eq(:png)
    end

    it "keeps resized images within the pixel limit" do
      [[301, 199, 4000], [199, 301, 4000], [301, 1, 1]].each do |width, height, max_pixels|
        ChunkyPNG::Image.new(width, height).save(input_path)

        described_class.thumbnail(
          input_path:,
          output_path:,
          max_pixels:,
          timeout: 20,
          operation: :optimized_image_downsize,
          read: [input_path],
          write: [directory],
        )

        output_width, output_height = FastImage.size(output_path)
        expect(output_width * output_height).to be <= max_pixels
      end
    end

    it "rejects conflicting resize targets" do
      expect {
        described_class.thumbnail(
          input_path:,
          output_path:,
          scale: 0.5,
          width: 100,
          height: 100,
          timeout: 20,
          operation: :optimized_image_downsize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(
        ArgumentError,
        "provide exactly one resize target: scale, width and height, or max_pixels",
      )
    end

    it "reports an invalid scale as an operation error" do
      expect {
        described_class.thumbnail(
          input_path:,
          output_path:,
          scale: 0,
          timeout: 20,
          operation: :optimized_image_downsize,
          read: [input_path],
          write: [directory],
        )
      }.to raise_error(DiscourseVips::Error, "invalid resize scale")
    end
  end
end
