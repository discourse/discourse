# frozen_string_literal: true

require "vips"

RSpec.describe OptimizedImage do
  describe ".resize" do
    shared_examples "in-place resizing" do
      it "resizes an image in place" do
        Dir.mktmpdir do |directory|
          path = File.join(directory, "image.png")
          FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), path)

          expect(described_class.resize(path, path, 30, 20, raise_on_error: true)).to eq(true)
          expect(FastImage.size(path)).to eq([30, 20])
        end
      end
    end

    it "honors explicit JPEG quality when the native renderer writes thumbnails" do
      global_setting :enable_vips_image_processing, true
      source = Rails.root.join("spec/fixtures/images/exif_orientation.jpg").to_s

      Dir.mktmpdir do |directory|
        low = File.join(directory, "low.jpg")
        high = File.join(directory, "high.jpg")

        described_class.resize(source, low, 45, 30, quality: 10, raise_on_error: true)
        described_class.resize(source, high, 45, 30, quality: 95, raise_on_error: true)

        expect(FastImage.type(low)).to eq(:jpeg)
        expect(FastImage.size(low)).to eq([45, 30])
        expect(File.size(low)).to be < File.size(high)
      end
    end

    context "with libvips disabled" do
      before { global_setting :enable_vips_image_processing, false }

      include_examples "in-place resizing"
    end

    context "with libvips enabled" do
      before { global_setting :enable_vips_image_processing, true }

      include_examples "in-place resizing"
    end
  end
end
