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
end
