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
end
