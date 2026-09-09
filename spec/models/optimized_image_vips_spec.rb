# frozen_string_literal: true

RSpec.describe OptimizedImage do
  describe ".downsize" do
    [false, true].each do |enable_vips|
      it "replaces an image in place with libvips #{enable_vips ? "enabled" : "disabled"}" do
        global_setting :enable_vips_image_processing, enable_vips

        Dir.mktmpdir do |directory|
          path = File.join(directory, "image.png")
          FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), path)
          width, height = FastImage.size(path)

          expect(described_class.downsize(path, path, "50%", raise_on_error: true)).to eq(true)
          expect(FastImage.size(path)).to eq([(width / 2.0).round, (height / 2.0).round])
        end
      end
    end

    it "retains lossless WebP encoding selected by the first animation frame" do
      source = Rails.root.join("spec/fixtures/images/webp-quality-first-frame.webp").to_s
      Dir.mktmpdir do |directory|
        [false, true].each do |enable_vips|
          global_setting :enable_vips_image_processing, enable_vips
          output = File.join(directory, "#{enable_vips}.webp")

          result = described_class.downsize(source, output, "384x1>", raise_on_error: true)

          expect(result).to eq(true)
          expect(ImageMagick.image_quality(input_path: output, timeout: 5)).to eq(100)
        end
      end
    end

    it "preserves the destination when native decoding fails and honors raise_on_error" do
      global_setting :enable_vips_image_processing, true

      Dir.mktmpdir do |directory|
        source = File.join(directory, "broken.png")
        destination = File.join(directory, "destination.png")
        File.write(source, "invalid image")
        File.write(destination, "original destination")

        expect(described_class.downsize(source, destination, "50%")).to eq(false)
        expect(File.read(destination)).to eq("original destination")
        expect do
          described_class.downsize(source, destination, "50%", raise_on_error: true)
        end.to raise_error(DiscourseVips::Error)
        expect(File.read(destination)).to eq("original destination")
      end
    end
  end

  describe ".resize" do
    [false, true].each do |enable_vips|
      it "resizes an image in place with libvips #{enable_vips ? "enabled" : "disabled"}" do
        global_setting :enable_vips_image_processing, enable_vips

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
  end

  describe ".crop" do
    [false, true].each do |enable_vips|
      it "crops an image in place with libvips #{enable_vips ? "enabled" : "disabled"}" do
        global_setting :enable_vips_image_processing, enable_vips

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
  end
end
