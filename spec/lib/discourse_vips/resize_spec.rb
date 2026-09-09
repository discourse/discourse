# frozen_string_literal: true

require "chunky_png"
require "vips"

RSpec.describe DiscourseVips do
  describe ".resize" do
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
            described_class.resize(
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

    include ImageOrientationHelpers

    it "centers a landscape and portrait image within the exact requested dimensions" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")
        [[90, 30], [30, 90]].each do |width, height|
          source = ChunkyPNG::Image.new(width, height, ChunkyPNG::Color.rgb(255, 0, 0))
          source.rect(
            width / 3,
            height / 3,
            width * 2 / 3 - 1,
            height * 2 / 3 - 1,
            ChunkyPNG::Color.rgb(0, 255, 0),
            ChunkyPNG::Color.rgb(0, 255, 0),
          )
          source.save(input_path)

          [false, true].each do |strip_metadata|
            described_class.resize(
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

            image = ChunkyPNG::Image.from_file(output_path)
            expect([image.width, image.height]).to eq([21, 21])
            expect(image[10, 10]).to eq(ChunkyPNG::Color.rgb(0, 255, 0))
          end
        end
      end
    end

    it "replaces the source atomically and retains partially transparent colors" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        color = ChunkyPNG::Color.rgba(0, 255, 0, 128)
        ChunkyPNG::Image.new(3, 7, color).save(input_path)

        described_class.resize(
          input_path:,
          output_path: input_path,
          input_format: "png",
          output_format: "png",
          width: 20,
          height: 30,
          quality: nil,
          strip_metadata: false,
          timeout: 20,
        )

        image = ChunkyPNG::Image.from_file(input_path)
        expect([image.width, image.height]).to eq([20, 30])
        expect(image[10, 15]).to eq(color)
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end

    it "retains the destination and removes temporary output on decode errors and timeouts" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "existing.png")
        File.binwrite(input_path, "invalid image")
        File.binwrite(output_path, "existing destination")

        expect {
          described_class.resize(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            width: 20,
            height: 20,
            quality: nil,
            strip_metadata: false,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
        File.unlink(input_path)
        File.mkfifo(input_path)
        File.open(input_path, File::RDWR) do
          expect {
            described_class.resize(
              input_path:,
              output_path:,
              input_format: "png",
              output_format: "png",
              width: 20,
              height: 20,
              quality: nil,
              strip_metadata: false,
              timeout: 0.05,
            )
          }.to raise_error(DiscourseVips::OperationTimeout)
        end

        expect(File.binread(output_path)).to eq("existing destination")
        expect(Dir.children(directory)).to contain_exactly("source.png", "existing.png")
      end
    end

    it "preserves the color profile with either metadata setting" do
      profile = File.binread(Rails.root.join("vendor/data/RT_sRGB.icm"))
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
        stream = ChunkyPNG::Datastream.from_file(input_path)
        stream.other_chunks << ChunkyPNG::Chunk::Generic.new(
          "iCCP",
          "profile\0\0".b + Zlib::Deflate.deflate(profile),
        )
        File.binwrite(input_path, stream.to_blob)

        [false, true].each do |strip_metadata|
          described_class.resize(
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

          chunks = ChunkyPNG::Datastream.from_file(output_path).other_chunks
          chunk = chunks.find { |entry| entry.type == "iCCP" }
          expect(
            Zlib::Inflate.inflate(chunk.content.byteslice((chunk.content.index("\0") + 2)..)),
          ).to eq(profile)
          expect(ChunkyPNG::Image.from_file(output_path)[10, 10]).to eq(
            ChunkyPNG::Color.rgb(255, 0, 0),
          )
        end
      end
    end

    it "auto-orients before selecting the center" do
      with_jpeg_orientation(
        source_path: file_from_fixtures("exif_orientation.jpg").path,
        orientation: 6,
      ) do |source|
        Dir.mktmpdir do |directory|
          output_path = File.join(directory, "resized.png")

          [false, true].each do |strip_metadata|
            described_class.resize(
              input_path: source.path,
              output_path:,
              input_format: "jpg",
              output_format: "png",
              width: 20,
              height: 30,
              quality: nil,
              strip_metadata:,
              timeout: 20,
            )

            image = ChunkyPNG::Image.from_file(output_path)
            palette = { cyan: [0, 255, 255], red: [255, 0, 0], blue: [0, 0, 255] }
            expect([image.width, image.height]).to eq([20, 30])
            expect(nearest_palette_color(pixel: image[5, 5], palette:)).to eq(:cyan)
            exif =
              ChunkyPNG::Datastream
                .from_file(output_path)
                .other_chunks
                .find { |chunk| chunk.type == "eXIf" }
            expect(exif.nil?).to eq(strip_metadata)
          end
        end
      end
    end

    it "sharpens a tonal boundary while preserving uniform regions" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")
        source = ChunkyPNG::Image.new(40, 20, ChunkyPNG::Color.rgb(80, 80, 80))
        source.rect(
          20,
          0,
          39,
          19,
          ChunkyPNG::Color.rgb(160, 160, 160),
          ChunkyPNG::Color.rgb(160, 160, 160),
        )
        source.save(input_path)

        [false, true].each do |strip_metadata|
          described_class.resize(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            width: 40,
            height: 20,
            quality: nil,
            strip_metadata:,
            timeout: 20,
          )

          image = ChunkyPNG::Image.from_file(output_path)
          expect(image[5, 10]).to eq(ChunkyPNG::Color.rgb(80, 80, 80))
          expect(image[35, 10]).to eq(ChunkyPNG::Color.rgb(160, 160, 160))
          expect(ChunkyPNG::Color.r(image[19, 10])).to be < 80
          expect(ChunkyPNG::Color.r(image[20, 10])).to be > 160
        end
      end
    end

    it "reduces thumbnail depth to eight bits while keeping ordinary resize depth" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        Vips::Image
          .black(60, 40)
          .cast(:ushort)
          .new_from_image([32_768, 8192, 65_535])
          .copy(interpretation: :rgb16)
          .pngsave(input_path)

        [false, true].each do |strip_metadata|
          output_path = File.join(directory, "resized-strip-#{strip_metadata}.png")
          described_class.resize(
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
          expect(image.format).to eq(strip_metadata ? :uchar : :ushort)
          expected_channels = strip_metadata ? [128, 32, 255] : [32_768, 8192, 65_535]
          image
            .getpoint(10, 10)
            .zip(expected_channels)
            .each { |actual, expected| expect(actual).to be_within(1).of(expected) }
          image
            .colourspace(:srgb)
            .getpoint(10, 10)
            .zip([128, 32, 255])
            .each { |actual, expected| expect(actual).to be_within(1).of(expected) }
        end
      end
    end

    it "requires explicit encoder quality and positive dimensions" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        ChunkyPNG::Image.new(3, 7, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
        original = File.binread(input_path)

        expect {
          described_class.resize(
            input_path:,
            output_path: input_path,
            input_format: "png",
            output_format: "jpg",
            width: 20,
            height: 20,
            quality: nil,
            strip_metadata: false,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "encoder quality is required")
        expect {
          described_class.resize(
            input_path:,
            output_path: input_path,
            input_format: "png",
            output_format: "png",
            width: 0,
            height: 20,
            quality: nil,
            strip_metadata: false,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "invalid resize dimensions")

        expect(File.binread(input_path)).to eq(original)
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end
  end
end
