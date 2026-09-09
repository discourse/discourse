# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  %i[resize crop downsize convert_to_jpeg auto_orient].each do |operation|
    describe ".#{operation}" do
      it "retains full chroma detail when the source uses uncommon sampling" do
        Dir.mktmpdir do |directory|
          %w[422 440].each do |sampling|
            input_path = Rails.root.join("spec/fixtures/images/jpeg-sampling-#{sampling}.jpg").to_s
            source_bytes = File.binread(input_path)
            modes = %i[resize crop].include?(operation) ? [false, true] : [false]
            modes.each do |strip_metadata|
              output_path = File.join(directory, "output-#{sampling}-#{strip_metadata}.jpg")
              arguments = { input_path:, output_path:, timeout: 20 }
              case operation
              when :resize, :crop
                arguments.merge!(
                  input_format: "jpeg",
                  output_format: "jpeg",
                  width: 30,
                  height: 20,
                  quality: 89,
                  strip_metadata:,
                )
              when :downsize
                arguments.merge!(
                  input_format: "jpeg",
                  output_format: "jpeg",
                  geometry: "50%",
                  quality: 89,
                )
              when :convert_to_jpeg
                arguments.merge!(input_format: "jpeg", quality: 89)
              when :auto_orient
                arguments.merge!(source_quality: 89)
              end

              described_class.public_send(operation, **arguments)

              output = Vips::Image.jpegload(output_path)
              expect(output.get("jpeg-chroma-subsample")).to eq("4:4:4")
              expect(File.binread(input_path)).to eq(source_bytes)
              if %i[convert_to_jpeg auto_orient].include?(operation)
                source = Vips::Image.jpegload(input_path)
                expect((source - output).abs.avg).to be < 2
              end
            end
          end
        end
      end

      it "preserves source JPEG chroma sampling independently of encoder quality" do
        Dir.mktmpdir do |directory|
          coordinates = Vips::Image.xyz(60, 40)
          image =
            (coordinates[0] * 4)
              .bandjoin(coordinates[1] * 6)
              .bandjoin(128)
              .cast(:uchar)
              .copy(interpretation: :srgb)

          [[:off, 89, "4:4:4"], [:on, 90, "4:2:0"]].each do |subsample_mode, quality, expected|
            input_path = File.join(directory, "source-#{subsample_mode}.jpg")
            image.jpegsave(input_path, Q: quality, subsample_mode:)
            source_bytes = File.binread(input_path)
            expect(Vips::Image.jpegload(input_path).get("jpeg-chroma-subsample")).to eq(expected)
            modes = %i[resize crop].include?(operation) ? [false, true] : [false]
            modes.each do |strip_metadata|
              output_path = File.join(directory, "output-#{subsample_mode}-#{strip_metadata}.jpg")
              arguments = { input_path:, output_path:, timeout: 20 }
              case operation
              when :resize, :crop
                arguments.merge!(
                  input_format: "jpeg",
                  output_format: "jpeg",
                  width: 30,
                  height: 20,
                  quality:,
                  strip_metadata:,
                )
              when :downsize
                arguments.merge!(
                  input_format: "jpeg",
                  output_format: "jpeg",
                  geometry: "50%",
                  quality:,
                )
              when :convert_to_jpeg
                arguments.merge!(input_format: "jpeg", quality:)
              when :auto_orient
                arguments.merge!(source_quality: quality)
              end

              described_class.public_send(operation, **arguments)

              expect(Vips::Image.jpegload(output_path).get("jpeg-chroma-subsample")).to eq(expected)
              expect(File.binread(input_path)).to eq(source_bytes)
            end
          end
        end
      end
    end
  end

  describe ".resize" do
    it "rejects truncated JPEG headers without replacing the destination" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "truncated.jpg")
        output_path = File.join(directory, "destination.jpg")
        File.binwrite(input_path, "\xFF\xD8\xFF\xE1\xFF\xFFmissing metadata".b)
        File.binwrite(output_path, "original destination")
        source_bytes = File.binread(input_path)

        expect do
          described_class.resize(
            input_path:,
            output_path:,
            input_format: "jpeg",
            output_format: "jpeg",
            width: 30,
            height: 20,
            quality: 89,
            strip_metadata: false,
            timeout: 20,
          )
        end.to raise_error(DiscourseVips::Error)

        expect(File.binread(input_path)).to eq(source_bytes)
        expect(File.binread(output_path)).to eq("original destination")
      end
    end
  end

  describe ".convert_to_jpeg" do
    it "uses the encoder quality threshold when a PNG has no source JPEG sampling" do
      Dir.mktmpdir do |directory|
        input_path = File.join(directory, "source.png")
        Vips::Image
          .black(30, 20)
          .new_from_image([40, 150, 230])
          .cast(:uchar)
          .copy(interpretation: :srgb)
          .pngsave(input_path)

        [[89, "4:2:0"], [90, "4:4:4"], [92, "4:4:4"]].each do |quality, expected|
          output_path = File.join(directory, "output-#{quality}.jpg")
          described_class.convert_to_jpeg(
            input_path:,
            output_path:,
            input_format: "png",
            quality:,
            timeout: 20,
          )

          expect(Vips::Image.jpegload(output_path).get("jpeg-chroma-subsample")).to eq(expected)
        end
      end
    end
  end
end
