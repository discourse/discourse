# frozen_string_literal: true

require "chunky_png"

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

        described_class.svg_to_png(
          input_path: file.path,
          output_path:,
          max_width: 300,
          max_height: 100,
          timeout: 5,
        )

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

    it "renders fractional SVG dimensions" do
      input_path = file_from_fixtures("tiny.svg").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(
          input_path:,
          output_path:,
          max_width: 300,
          max_height: 100,
          timeout: 5,
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([115, 86])
      end
    end

    it "renders SVG filters" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="50" height="50">
          <defs>
            <filter id="blur"><feGaussianBlur stdDeviation="1"/></filter>
          </defs>
          <rect width="50" height="50" fill="#ff0000" filter="url(#blur)"/>
        </svg>
      SVG
      file = file_from_contents(svg, "filter.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(
          input_path: file.path,
          output_path:,
          max_width: 300,
          max_height: 100,
          timeout: 3,
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([50, 50])
      end
    end

    it "rejects a zero-sized SVG without writing a PNG" do
      input_path = file_from_fixtures("zero_sized.svg").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(
            input_path:,
            output_path:,
            max_width: 300,
            max_height: 100,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
        expect(File.exist?(output_path)).to eq(false)
      end
    end

    it "rejects malformed SVGs without writing a PNG" do
      file = file_from_contents('<svg width="100" height="50">', "invalid.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            max_width: 300,
            max_height: 100,
            timeout: 5,
          )
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
            max_width: 300,
            max_height: 100,
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

        expect {
          described_class.svg_to_png(
            input_path:,
            output_path:,
            max_width: 300,
            max_height: 100,
            timeout: 5,
          )
        }.to raise_error(DiscourseVips::Error, "SVG input and PNG output must be different files")
        expect(File.read(input_path)).to eq(svg)
      end
    end

    it "bounds SVGs with enormous declared dimensions" do
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="1000000" height="1000000">
          <rect width="1000000" height="1000000" fill="#ff0000"/>
        </svg>
      SVG
      file = file_from_contents(svg, "enormous.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")

        described_class.svg_to_png(
          input_path: file.path,
          output_path:,
          max_width: 300,
          max_height: 100,
          timeout: 5,
        )

        png = ChunkyPNG::Image.from_file(output_path)
        expect([png.width, png.height]).to eq([100, 100])
      end
    end

    it "bounds dense SVG filter graphs and keeps the worker available" do
      filter_primitives =
        10_000
          .times
          .map do |index|
            input = index.zero? ? "SourceGraphic" : "blur#{index - 1}"
            %(<feGaussianBlur in="#{input}" result="blur#{index}" stdDeviation="5"/>)
          end
          .join
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="300" height="100">
          <defs><filter id="dense">#{filter_primitives}</filter></defs>
          <rect width="300" height="100" fill="#ff0000" filter="url(#dense)"/>
        </svg>
      SVG
      file = file_from_contents(svg, "dense-filter.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            max_width: 300,
            max_height: 100,
            timeout: 3,
          )
        }.to raise_error(DiscourseVips::Error) do |error|
          expect(error).not_to be_a(DiscourseVips::OperationTimeout)
        end
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 2.5
        expect(File.exist?(output_path)).to eq(false)
        expect(Dir.children(directory)).to be_empty
      end

      expect(described_class.version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "preserves an existing output when SVG rendering fails" do
      file = file_from_contents('<svg width="100" height="50">', "invalid.svg")

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "output.png")
        File.write(output_path, "existing")

        expect {
          described_class.svg_to_png(
            input_path: file.path,
            output_path:,
            max_width: 300,
            max_height: 100,
            timeout: 3,
          )
        }.to raise_error(DiscourseVips::Error)
        expect(File.read(output_path)).to eq("existing")
        expect(Dir.children(directory)).to contain_exactly("output.png")
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
