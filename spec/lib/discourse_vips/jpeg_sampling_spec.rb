# frozen_string_literal: true

require "vips"

RSpec.describe DiscourseVips do
  describe ".auto_orient" do
    it "retains full chroma detail when the source uses uncommon sampling" do
      Dir.mktmpdir do |directory|
        %w[422 440].each do |sampling|
          input_path = Rails.root.join("spec/fixtures/images/jpeg-sampling-#{sampling}.jpg").to_s
          source_bytes = File.binread(input_path)
          output_path = File.join(directory, "output-#{sampling}.jpg")
          described_class.auto_orient(input_path:, output_path:, source_quality: 89, timeout: 20)

          output = Vips::Image.jpegload(output_path)
          expect(output.get("jpeg-chroma-subsample")).to eq("4:4:4")
          expect(File.binread(input_path)).to eq(source_bytes)
          source = Vips::Image.jpegload(input_path)
          expect((source - output).abs.avg).to be < 2
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
          output_path = File.join(directory, "output-#{subsample_mode}.jpg")
          described_class.auto_orient(
            input_path:,
            output_path:,
            source_quality: quality,
            timeout: 20,
          )

          expect(Vips::Image.jpegload(output_path).get("jpeg-chroma-subsample")).to eq(expected)
          expect(File.binread(input_path)).to eq(source_bytes)
        end
      end
    end
  end
end
