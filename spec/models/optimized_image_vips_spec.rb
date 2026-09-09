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
end
