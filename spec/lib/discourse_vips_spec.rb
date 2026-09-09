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
