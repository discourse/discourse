# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  describe ".resize" do
    it "retains full chroma detail when the source uses uncommon sampling" do
      Dir.mktmpdir do |directory|
        %w[422 440].each do |sampling|
          input_path = Rails.root.join("spec/fixtures/images/jpeg-sampling-#{sampling}.jpg").to_s
          source_bytes = File.binread(input_path)
          modes = [false, true]
          modes.each do |strip_metadata|
            output_path = File.join(directory, "output-#{sampling}-#{strip_metadata}.jpg")
            arguments = { input_path:, output_path:, timeout: 20 }
            arguments.merge!(
              input_format: "jpeg",
              output_format: "jpeg",
              width: 30,
              height: 20,
              quality: 89,
              strip_metadata:,
            )

            described_class.resize(**arguments)

            output = Vips::Image.jpegload(output_path)
            expect(output.get("jpeg-chroma-subsample")).to eq("4:4:4")
            expect(File.binread(input_path)).to eq(source_bytes)
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
          modes = [false, true]
          modes.each do |strip_metadata|
            output_path = File.join(directory, "output-#{subsample_mode}-#{strip_metadata}.jpg")
            arguments = { input_path:, output_path:, timeout: 20 }
            arguments.merge!(
              input_format: "jpeg",
              output_format: "jpeg",
              width: 30,
              height: 20,
              quality:,
              strip_metadata:,
            )

            described_class.resize(**arguments)

            expect(Vips::Image.jpegload(output_path).get("jpeg-chroma-subsample")).to eq(expected)
            expect(File.binread(input_path)).to eq(source_bytes)
          end
        end
      end
    end

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
end
