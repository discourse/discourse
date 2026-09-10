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

  describe ".crop" do
    { rgb16: [32_768, 8192, 65_535], grey16: [32_768] }.each do |interpretation, channels|
      [false, true].each do |alpha|
        it "preserves #{interpretation} channel values with alpha #{alpha} across crop depth modes" do
          Dir.mktmpdir do |directory|
            input_path = File.join(directory, "source.png")
            source_channels = alpha ? channels + [32_768] : channels
            Vips::Image
              .black(60, 40)
              .cast(:ushort)
              .new_from_image(source_channels)
              .copy(interpretation:)
              .pngsave(input_path, bitdepth: 16)

            [false, true].each do |strip_metadata|
              output_path = File.join(directory, "cropped-#{strip_metadata}.png")

              described_class.crop(
                input_path:,
                output_path:,
                input_format: "png",
                output_format: "png",
                width: 21,
                height: 21,
                quality: nil,
                strip_metadata:,
                timeout: 20,
              )

              expect(File.binread(output_path, 25).getbyte(24)).to eq(strip_metadata ? 8 : 16)
              image = Vips::Image.pngload(output_path)
              expect([image.width, image.height]).to eq([21, 21])
              expect(image.has_alpha?).to eq(alpha)
              expected_channels =
                strip_metadata ? source_channels.map { |channel| channel / 256 } : source_channels
              image
                .getpoint(10, 10)
                .zip(expected_channels)
                .each { |actual, expected| expect(actual).to be_within(1).of(expected) }
            end
          end
        end
      end
    end

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
