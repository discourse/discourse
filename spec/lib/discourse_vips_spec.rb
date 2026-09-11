# frozen_string_literal: true

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
