# frozen_string_literal: true

require "vips"

RSpec.describe OptimizedImage do
  describe ".crop" do
    shared_examples "eight-bit stripped PNG cropping" do
      it "keeps stripped 16-bit PNG crops at eight bits after optimization" do
        SiteSetting.strip_image_metadata = true

        Dir.mktmpdir do |directory|
          source = File.join(directory, "source.png")
          Vips::Image
            .new_from_memory(Random.new(123).bytes(512 * 512 * 3 * 2), 512, 512, 3, :ushort)
            .copy(interpretation: :rgb16)
            .pngsave(source, bitdepth: 16)

          output = File.join(directory, "output.png")

          result = described_class.crop(source, output, 480, 480, raise_on_error: true)

          expect(result).to eq(true)
          expect(FastImage.size(output)).to eq([480, 480])
          expect(File.binread(output, 25).getbyte(24)).to eq(8)
        end
      end
    end

    shared_examples "in-place cropping" do
      it "crops an image in place" do
        Dir.mktmpdir do |directory|
          path = File.join(directory, "image.png")
          FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), path)

          expect(described_class.crop(path, path, 30, 20, raise_on_error: true)).to eq(true)
          expect(FastImage.size(path)).to eq([30, 20])
        end
      end
    end

    it "honors explicit JPEG quality when the native renderer crops thumbnails" do
      global_setting :enable_vips_image_processing, true
      source = Rails.root.join("spec/fixtures/images/exif_orientation.jpg").to_s

      Dir.mktmpdir do |directory|
        low = File.join(directory, "low.jpg")
        high = File.join(directory, "high.jpg")

        described_class.crop(source, low, 45, 30, quality: 10, raise_on_error: true)
        described_class.crop(source, high, 45, 30, quality: 95, raise_on_error: true)

        expect(FastImage.type(low)).to eq(:jpeg)
        expect(FastImage.size(low)).to eq([45, 30])
        expect(File.size(low)).to be < File.size(high)
      end
    end

    context "with libvips disabled" do
      before { global_setting :enable_vips_image_processing, false }

      include_examples "eight-bit stripped PNG cropping"
      include_examples "in-place cropping"
    end

    context "with libvips enabled" do
      before { global_setting :enable_vips_image_processing, true }

      include_examples "eight-bit stripped PNG cropping"
      include_examples "in-place cropping"
    end
  end
end
