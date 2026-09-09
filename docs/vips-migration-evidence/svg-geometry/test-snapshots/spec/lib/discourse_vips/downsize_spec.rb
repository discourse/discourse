require "chunky_png"

RSpec.describe DiscourseVips do
  describe ".downsize" do
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
          described_class.downsize(
            input_path:,
            output_path:,
            input_format: "svg",
            output_format: "png",
            geometry: "50%",
            quality: nil,
            timeout: 20,
          )

          image = ChunkyPNG::Image.from_file(output_path)
          expect([image.width, image.height]).to eq([50, 25])
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

    include ImageOrientationHelpers

    it "rounds percentage, bounding-box, and area geometries like existing uploads" do
      cases = {
        [101, 51] => [[51, 26], [100, 50], [45, 22]],
        [51, 101] => [[26, 51], [50, 100], [22, 45]],
        [3, 7] => [[2, 4], [3, 7], [21, 48]],
        [1, 1] => [[1, 1], [1, 1], [32, 32]],
        [244, 66] => [[122, 33], [100, 27], [61, 16]],
      }

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")

        cases.each do |(width, height), expected_dimensions|
          ChunkyPNG::Image.new(width, height, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

          %w[50% 100x100> 1000@]
            .zip(expected_dimensions)
            .each do |geometry, dimensions|
              described_class.downsize(
                input_path:,
                output_path:,
                input_format: "png",
                output_format: "png",
                geometry:,
                quality: nil,
                timeout: 20,
              )

              image = ChunkyPNG::Image.from_file(output_path)
              expect([image.width, image.height]).to eq(dimensions)
              expect(image[image.width / 2, image.height / 2]).to eq(
                ChunkyPNG::Color.rgb(255, 0, 0),
              )
            end
        end
      end
    end

    it "keeps pixel edges centered when a percentage geometry enlarges an image" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")

        [128, 255].each do |alpha|
          source = ChunkyPNG::Image.new(40, 40, ChunkyPNG::Color.rgba(255, 255, 255, alpha))
          black = ChunkyPNG::Color.rgba(0, 0, 0, alpha)
          20.upto(39) { |row| 20.upto(39) { |column| source[column, row] = black } }
          source.save(input_path)

          %w[125% 200%].each do |geometry|
            described_class.downsize(
              input_path:,
              output_path:,
              input_format: "png",
              output_format: "png",
              geometry:,
              quality: nil,
              timeout: 20,
            )
            image = ChunkyPNG::Image.from_file(output_path)
            center = image.width / 2

            expect(ChunkyPNG::Color.r(image[center - 1, center - 1])).to be > 220
            expect(ChunkyPNG::Color.r(image[center, center])).to be < 110
            expect(ChunkyPNG::Color.a(image[center, center])).to eq(alpha)
          end
        end
      end
    end

    it "replaces an input only after successful in-place resizing" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgba(0, 255, 0, 128)).save(input_path)

        described_class.downsize(
          input_path:,
          output_path: input_path,
          input_format: "png",
          output_format: "png",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )

        image = ChunkyPNG::Image.from_file(input_path)
        expect([image.width, image.height]).to eq([30, 20])
        expect(image[15, 10]).to eq(ChunkyPNG::Color.rgba(0, 255, 0, 128))
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end

    it "keeps an existing destination and removes temporary output when decoding fails" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "invalid.png")
        output_path = File.join(directory, "existing.png")
        File.binwrite(input_path, "invalid image")
        File.binwrite(output_path, "original destination")

        expect {
          described_class.downsize(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            geometry: "50%",
            quality: nil,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage)

        expect(File.binread(output_path)).to eq("original destination")
        expect(Dir.children(directory)).to contain_exactly("invalid.png", "existing.png")
      end
    end

    it "keeps the destination and cleans up when the decoder times out" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "blocked.png")
        output_path = File.join(directory, "existing.png")
        File.mkfifo(input_path)
        File.binwrite(output_path, "original destination")

        File.open(input_path, File::RDWR) do
          expect {
            described_class.downsize(
              input_path:,
              output_path:,
              input_format: "png",
              output_format: "png",
              geometry: "50%",
              quality: nil,
              timeout: 0.05,
            )
          }.to raise_error(DiscourseVips::OperationTimeout)
        end

        expect(File.binread(output_path)).to eq("original destination")
        expect(Dir.children(directory)).to contain_exactly("blocked.png", "existing.png")
      end
    end

    it "requires explicit quality for lossy encoders and preserves the source on invalid geometry" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        ChunkyPNG::Image.new(3, 7, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
        original = File.binread(input_path)

        %w[jpg webp avif].each do |output_format|
          expect {
            described_class.downsize(
              input_path:,
              output_path: input_path,
              input_format: "png",
              output_format:,
              geometry: "50%",
              quality: nil,
              timeout: 20,
            )
          }.to raise_error(DiscourseVips::InvalidImage, "encoder quality is required")
        end
        expect {
          described_class.downsize(
            input_path:,
            output_path: input_path,
            input_format: "png",
            output_format: "png",
            geometry: "0%",
            quality: nil,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "invalid resize geometry")

        expect(File.binread(input_path)).to eq(original)
        expect(Dir.children(directory)).to eq(["source.png"])
      end
    end

    it "uses the explicitly selected decoder even when the filename has another extension" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.jpg")
        output_path = File.join(directory, "resized.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        expect {
          described_class.downsize(
            input_path:,
            output_path:,
            input_format: "jpg",
            output_format: "png",
            geometry: "50%",
            quality: nil,
            timeout: 20,
          )
        }.to raise_error(DiscourseVips::InvalidImage)
        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "png",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )

        expect(FastImage.size(output_path)).to eq([30, 20])
      end
    end

    it "selects the first ICO image before resizing" do
      input_path = file_from_fixtures("ico-last-bmp.ico").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "resized.png")

        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "ico",
          output_format: "png",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )

        image = ChunkyPNG::Image.from_file(output_path)
        expect([image.width, image.height]).to eq([32, 32])
        expect(image[5, 8]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
      end
    end

    it "preserves the embedded color profile without attaching one to untagged inputs" do
      profile = File.binread(Rails.root.join("vendor/data/RT_sRGB.icm"))

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.png")

        [false, true].each do |tagged|
          ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
          if tagged
            stream = ChunkyPNG::Datastream.from_file(input_path)
            stream.other_chunks << ChunkyPNG::Chunk::Generic.new(
              "iCCP",
              "profile\0\0".b + Zlib::Deflate.deflate(profile),
            )
            File.binwrite(input_path, stream.to_blob)
          end

          described_class.downsize(
            input_path:,
            output_path:,
            input_format: "png",
            output_format: "png",
            geometry: "50%",
            quality: nil,
            timeout: 20,
          )

          chunk =
            ChunkyPNG::Datastream
              .from_file(output_path)
              .other_chunks
              .find { |entry| entry.type == "iCCP" }
          if tagged
            expect(
              Zlib::Inflate.inflate(chunk.content.byteslice((chunk.content.index("\0") + 2)..)),
            ).to eq(profile)
          else
            expect(chunk).to be_nil
          end
          expect(ChunkyPNG::Image.from_file(output_path)[15, 10]).to eq(
            ChunkyPNG::Color.rgb(255, 0, 0),
          )
        end
      end
    end

    it "auto-orients the pixels before applying the bounds" do
      with_jpeg_orientation(
        source_path: file_from_fixtures("exif_orientation.jpg").path,
        orientation: 6,
      ) do |source|
        Dir.mktmpdir do |directory|
          output_path = File.join(directory, "resized.png")

          described_class.downsize(
            input_path: source.path,
            output_path:,
            input_format: "jpg",
            output_format: "png",
            geometry: "20x20>",
            quality: nil,
            timeout: 20,
          )

          image = ChunkyPNG::Image.from_file(output_path)
          expect([image.width, image.height]).to eq([13, 20])
          expect(
            nearest_palette_color(
              pixel: image[3, 3],
              palette: {
                cyan: [0, 255, 255],
                red: [255, 0, 0],
                blue: [0, 0, 255],
              },
            ),
          ).to eq(:cyan)
        end
      end
    end

    it "writes and reads each supported raster codec" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        decoded_path = File.join(directory, "decoded.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)

        %w[jpg png gif webp avif ico].each do |output_format|
          output_path = File.join(directory, "resized.#{output_format}")

          described_class.downsize(
            input_path:,
            output_path:,
            input_format: "png",
            output_format:,
            geometry: "50%",
            quality: 100,
            timeout: 20,
          )
          described_class.downsize(
            input_path: output_path,
            output_path: decoded_path,
            input_format: output_format,
            output_format: "png",
            geometry: "100%",
            quality: nil,
            timeout: 20,
          )

          expect(FastImage.type(output_path)).to eq(
            output_format == "jpg" ? :jpeg : output_format.to_sym,
          )
          image = ChunkyPNG::Image.from_file(decoded_path)
          expect([image.width, image.height]).to eq([30, 20])
          expect(ChunkyPNG::Color.r(image[15, 10])).to be_within(5).of(255)
          expect(ChunkyPNG::Color.g(image[15, 10])).to be_within(5).of(0)
          expect(ChunkyPNG::Color.b(image[15, 10])).to be_within(5).of(0)
        end
      end
    end

    it "drops JPEG alpha without blending partially transparent colors" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.jpg")
        decoded_path = File.join(directory, "decoded.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgba(0, 255, 0, 128)).save(input_path)

        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "jpg",
          geometry: "50%",
          quality: 100,
          timeout: 20,
        )
        described_class.downsize(
          input_path: output_path,
          output_path: decoded_path,
          input_format: "jpg",
          output_format: "png",
          geometry: "100%",
          quality: nil,
          timeout: 20,
        )

        pixel = ChunkyPNG::Image.from_file(decoded_path)[15, 10]
        expect(ChunkyPNG::Color.r(pixel)).to be_within(5).of(0)
        expect(ChunkyPNG::Color.g(pixel)).to be_within(5).of(255)
        expect(ChunkyPNG::Color.b(pixel)).to be_within(5).of(0)
      end
    end

    it "preserves the transparent shape boundary when resizing a GIF" do
      input_path = file_from_fixtures("animated.gif").path

      Dir.mktmpdir do |directory|
        output_path = File.join(directory, "resized.gif")
        actual_path = File.join(directory, "actual.png")
        reference_path = File.join(directory, "reference.png")
        reference_gif_path = File.join(directory, "reference.gif")
        ImageMagick.magick(
          "gif:#{input_path}[0]",
          "-auto-orient",
          "-resize",
          "50%",
          "gif:#{reference_gif_path}",
          operation: :optimized_image_downsize,
          read: [input_path],
          write: [directory],
        )
        ImageMagick.magick(
          "gif:#{reference_gif_path}[0]",
          "png:#{reference_path}",
          operation: :optimized_image_downsize,
          read: [reference_gif_path],
          write: [directory],
        )

        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "gif",
          output_format: "gif",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )
        described_class.downsize(
          input_path: output_path,
          output_path: actual_path,
          input_format: "gif",
          output_format: "png",
          geometry: "100%",
          quality: nil,
          timeout: 20,
        )

        expected = ChunkyPNG::Image.from_file(reference_path)
        actual = ChunkyPNG::Image.from_file(actual_path)
        expect([actual.width, actual.height]).to eq([160, 160])
        expect(actual.pixels.map { |pixel| ChunkyPNG::Color.a(pixel) }).to eq(
          expected.pixels.map { |pixel| ChunkyPNG::Color.a(pixel) },
        )
      end
    end

    it "preserves the embedded color profile when writing a GIF" do
      profile = File.binread(Rails.root.join("vendor/data/RT_sRGB.icm"))

      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        output_path = File.join(directory, "resized.gif")
        decoded_path = File.join(directory, "decoded.png")
        ChunkyPNG::Image.new(60, 40, ChunkyPNG::Color.rgb(255, 0, 0)).save(input_path)
        stream = ChunkyPNG::Datastream.from_file(input_path)
        stream.other_chunks << ChunkyPNG::Chunk::Generic.new(
          "iCCP",
          "profile\0\0".b + Zlib::Deflate.deflate(profile),
        )
        File.binwrite(input_path, stream.to_blob)

        described_class.downsize(
          input_path:,
          output_path:,
          input_format: "png",
          output_format: "gif",
          geometry: "50%",
          quality: nil,
          timeout: 20,
        )
        ImageMagick.magick(
          "gif:#{output_path}[0]",
          "png:#{decoded_path}",
          operation: :optimized_image_downsize,
          read: [output_path],
          write: [directory],
        )

        chunk =
          ChunkyPNG::Datastream
            .from_file(decoded_path)
            .other_chunks
            .find { |entry| entry.type == "iCCP" }
        expect(
          Zlib::Inflate.inflate(chunk.content.byteslice((chunk.content.index("\0") + 2)..)),
        ).to eq(profile)
        expect(ChunkyPNG::Image.from_file(decoded_path)[15, 10]).to eq(
          ChunkyPNG::Color.rgb(255, 0, 0),
        )
      end
    end
  end
end
