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
