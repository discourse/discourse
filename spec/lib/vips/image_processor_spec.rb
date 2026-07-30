# frozen_string_literal: true

RSpec.describe Vips do
  let(:fixture_directory) { Rails.root.join("spec/fixtures/images") }
  let(:high_detail_input) { fixture_directory.join("large_and_unoptimized.png").to_s }
  let(:transparent_input) { fixture_directory.join("logo.png").to_s }

  def write_oriented_jpeg(source:, target:, orientation:)
    Vips.call(
      "copy",
      source,
      "#{target}[Q=82,strip=true]",
      read: [source],
      write: [File.dirname(target)],
    )

    jpeg = File.binread(target)
    tiff =
      "II".b + [42].pack("v") + [8].pack("V") + [1].pack("v") + [0x0112, 3].pack("v2") +
        [1].pack("V") + [orientation, 0].pack("v2") + [0].pack("V")
    payload = "Exif\0\0".b + tiff
    segment = "\xFF\xE1".b + [payload.bytesize + 2].pack("n") + payload
    File.binwrite(target, jpeg.byteslice(0, 2) + segment + jpeg.byteslice(2..))
  end

  describe ".resize" do
    it "processes every supported raster input format" do
      Dir.mktmpdir("vips-format-matrix") do |directory|
        inputs = {
          "jpeg" => fixture_directory.join("logo.jpg").to_s,
          "png" => high_detail_input,
          "gif" => fixture_directory.join("animated.gif").to_s,
          "webp" => fixture_directory.join("animated.webp").to_s,
          "heic" => fixture_directory.join("should_be_jpeg.heic").to_s,
        }

        %w[avif jxl tiff].each do |format|
          path = File.join(directory, "input.#{format}")
          Vips.call(
            "copy",
            high_detail_input,
            path,
            read: [high_detail_input],
            write: [directory],
            allow_untrusted: format == "jxl",
          )
          inputs[format] = path
        end

        dimensions =
          inputs.to_h do |format, input|
            output = File.join(directory, "#{format}.png")
            described_class.resize(
              from: input,
              to: output,
              dimensions: "96x64",
              source_format: format,
              target_format: "png",
            )
            [format, FastImage.size(output)]
          end

        expect(dimensions).to eq(inputs.transform_values { [96, 64] })
      end
    end

    it "follows the metadata-stripping setting" do
      Dir.mktmpdir("vips-metadata") do |directory|
        preserved = File.join(directory, "preserved.png")
        stripped = File.join(directory, "stripped.png")

        SiteSetting.composer_media_optimization_image_enabled = false
        SiteSetting.strip_image_metadata = false
        described_class.resize(
          from: high_detail_input,
          to: preserved,
          dimensions: "320x200",
          source_format: "png",
          target_format: "png",
        )

        SiteSetting.strip_image_metadata = true
        described_class.resize(
          from: high_detail_input,
          to: stripped,
          dimensions: "320x200",
          source_format: "png",
          target_format: "png",
        )

        expect(Vips.header(preserved, field: "xmp-data")).not_to be_empty
        expect(Vips.header(preserved, field: "icc-profile-data")).not_to be_empty
        expect { Vips.header(stripped, field: "xmp-data") }.to raise_error(
          Discourse::Utils::CommandError,
        )
        expect(Vips.header(stripped, field: "icc-profile-data")).not_to be_empty
      end
    end

    it "rejects malformed input without creating output" do
      Dir.mktmpdir("vips-malformed") do |directory|
        input = File.join(directory, "input.png")
        output = File.join(directory, "output.png")
        File.binwrite(input, "not an image")

        expect do
          described_class.resize(
            from: input,
            to: output,
            dimensions: "50x50",
            source_format: "png",
            target_format: "png",
          )
        end.to raise_error(Discourse::Utils::CommandError)
        expect(File.exist?(output)).to eq(false)
      end
    end
  end

  describe ".crop" do
    it "produces an exact north-gravity crop for uncommon aspect ratios" do
      Dir.mktmpdir("vips-crop") do |directory|
        output = File.join(directory, "crop.png")

        described_class.crop(
          from: high_detail_input,
          to: output,
          dimensions: "173x419",
          source_format: "png",
          target_format: "png",
        )

        expect(FastImage.size(output)).to eq([173, 419])
      end
    end
  end

  describe ".downsize" do
    it "preserves aspect ratio for percentage, area, and shrink-only geometries" do
      Dir.mktmpdir("vips-downsize") do |directory|
        percentage = File.join(directory, "percentage.png")
        area = File.join(directory, "area.png")
        shrink_only = File.join(directory, "shrink-only.png")

        described_class.downsize(
          from: high_detail_input,
          to: percentage,
          dimensions: "50%",
          source_format: "png",
          target_format: "png",
        )
        described_class.downsize(
          from: high_detail_input,
          to: area,
          dimensions: "500000@",
          source_format: "png",
          target_format: "png",
        )
        described_class.downsize(
          from: transparent_input,
          to: shrink_only,
          dimensions: "500x500>",
          source_format: "png",
          target_format: "png",
        )

        area_width, area_height = FastImage.size(area)
        transparent_pixel =
          Vips.call("getpoint", shrink_only, "0", "0", read: [shrink_only]).split.map(&:to_f)
        expect(
          {
            percentage: FastImage.size(percentage),
            area_within_limit: area_width * area_height <= 500_000,
            shrink_only: FastImage.size(shrink_only),
            transparent_bands: Vips.header(shrink_only, field: "bands").to_i,
            transparent_alpha: transparent_pixel.last,
          },
        ).to match(
          {
            percentage: [1016, 656],
            area_within_limit: true,
            shrink_only: [244, 66],
            transparent_bands: 4,
            transparent_alpha: 0,
          },
        )
      end
    end
  end

  describe ".convert" do
    it "flattens transparency onto white and applies JPEG quality" do
      Dir.mktmpdir("vips-convert") do |directory|
        output = File.join(directory, "converted.jpg")

        described_class.convert(
          from: transparent_input,
          to: output,
          source_format: "png",
          target_format: "jpg",
          flatten: true,
          quality: 73,
        )

        corner = Vips.call("getpoint", output, "0", "0", read: [output]).split.map(&:to_f)

        expect(
          {
            dimensions: FastImage.size(output),
            format: FastImage.type(output),
            bands: Vips.header(output, field: "bands").to_i,
            corner: corner,
            quality: Vips.jpeg_quality(output),
          },
        ).to match(
          {
            dimensions: [244, 66],
            format: :jpeg,
            bands: 3,
            corner: satisfy { |values| values.all? { |value| value >= 254 } },
            quality: 73,
          },
        )
      end
    end
  end

  describe ".autorot" do
    it "matches ImageMagick for every non-default EXIF orientation" do
      Dir.mktmpdir("vips-autorot") do |directory|
        results =
          (2..8).to_h do |orientation|
            image_magick = File.join(directory, "image-magick-#{orientation}.jpg")
            vips = File.join(directory, "vips-#{orientation}.jpg")
            difference = File.join(directory, "difference-#{orientation}.v")
            absolute = File.join(directory, "absolute-#{orientation}.v")
            write_oriented_jpeg(source: high_detail_input, target: image_magick, orientation:)
            FileUtils.cp(image_magick, vips)

            ImageMagick.magick(
              "jpeg:#{image_magick}",
              "-auto-orient",
              "jpeg:#{image_magick}",
              read: [image_magick],
              write: [directory, image_magick],
              timeout: 20,
            )
            described_class.autorot(path: vips, format: "jpg", quality: 82)
            Vips.call(
              "subtract",
              image_magick,
              vips,
              difference,
              read: [image_magick, vips],
              write: [directory],
              allow_untrusted: true,
            )
            Vips.call(
              "abs",
              difference,
              absolute,
              read: [difference],
              write: [directory],
              allow_untrusted: true,
            )

            [
              orientation,
              {
                dimensions: [FastImage.size(image_magick), FastImage.size(vips)],
                orientation: Vips.header(vips, field: "orientation").to_i,
                quality: Vips.jpeg_quality(vips),
                normalized_channel_error:
                  Vips.call("avg", absolute, read: [absolute], allow_untrusted: true).to_f / 255,
              },
            ]
          end

        expect(results.values).to all(
          match(
            dimensions: satisfy { |dimensions| dimensions.uniq.one? },
            orientation: 1,
            quality: 82,
            normalized_channel_error: be <= 0.1,
          ),
        )
      end
    end
  end

  describe ".dimensions" do
    it "accounts for EXIF orientation when requested" do
      Dir.mktmpdir("vips-dimensions") do |directory|
        path = File.join(directory, "oriented.jpg")
        write_oriented_jpeg(source: high_detail_input, target: path, orientation: 6)

        expect(
          {
            stored: described_class.dimensions(path, format: "jpg"),
            upright: described_class.dimensions(path, format: "jpg", auto_orient: true),
          },
        ).to eq(stored: [2032, 1312], upright: [1312, 2032])
      end
    end
  end

  describe ".frame_count" do
    it "reports static and animated frame counts" do
      Dir.mktmpdir("vips-animated-avif") do |directory|
        first = File.join(directory, "first.v")
        second = File.join(directory, "second.v")
        joined = File.join(directory, "joined.v")
        avif = File.join(directory, "animated.avif")
        Vips.call(
          "black",
          first,
          "16",
          "16",
          "--bands",
          "3",
          write: [directory],
          allow_untrusted: true,
        )
        Vips.call("invert", first, second, read: [first], write: [directory], allow_untrusted: true)
        Vips.call(
          "arrayjoin",
          "#{first} #{second}",
          joined,
          "--across",
          "1",
          read: [first, second],
          write: [directory],
          allow_untrusted: true,
        )
        Vips.call(
          "copy",
          joined,
          "#{avif}[page-height=16,Q=80]",
          read: [joined],
          write: [directory],
          allow_untrusted: true,
        )

        expect(
          {
            static: described_class.frame_count(transparent_input, format: "png"),
            gif:
              described_class.frame_count(
                fixture_directory.join("animated.gif").to_s,
                format: "gif",
              ),
            webp:
              described_class.frame_count(
                fixture_directory.join("animated.webp").to_s,
                format: "webp",
              ),
            avif: described_class.frame_count(avif, format: "avif"),
          },
        ).to eq(static: 1, gif: 20, webp: 67, avif: 2)
      end
    end
  end

  describe ".rotated?" do
    it "detects orientations whose upright dimensions are transposed" do
      Dir.mktmpdir("vips-rotated") do |directory|
        path = File.join(directory, "oriented.jpg")
        write_oriented_jpeg(source: high_detail_input, target: path, orientation: 6)

        expect(described_class.rotated?(path, format: "jpg")).to eq(true)
      end
    end
  end

  describe ".svg_dimensions" do
    it "matches pixel, physical-unit, and zero-sized viewBox dimensions" do
      dimensions =
        %w[image.svg tiny.svg massive.svg zero_sized.svg].to_h do |filename|
          [filename, described_class.svg_dimensions(fixture_directory.join(filename).to_s)]
        end

      expect(dimensions).to eq(
        "image.svg" => [100, 50],
        "tiny.svg" => [115, 86],
        "massive.svg" => [11_520, 11_615],
        "zero_sized.svg" => [120, 90],
      )
    end
  end
end
