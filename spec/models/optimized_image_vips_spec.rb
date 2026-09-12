# frozen_string_literal: true

RSpec.describe OptimizedImage do
  describe ".downsize" do
    shared_examples "in-place downsizing" do
      it "replaces the image in place" do
        Dir.mktmpdir do |directory|
          path = File.join(directory, "image.png")
          FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), path)
          width, height = FastImage.size(path)

          expect(described_class.downsize(path, path, "50%", raise_on_error: true)).to eq(true)
          expect(FastImage.size(path)).to eq([(width / 2.0).round, (height / 2.0).round])
        end
      end
    end

    context "with libvips disabled" do
      before { global_setting :enable_vips_image_processing, false }

      include_examples "in-place downsizing"
    end

    context "with libvips enabled" do
      before { global_setting :enable_vips_image_processing, true }

      include_examples "in-place downsizing"
    end

    it "does not use ImageMagick for unsupported ICO input" do
      global_setting :enable_vips_image_processing, true
      source = file_from_fixtures("smallest.ico").path
      allow(ImageMagick).to receive(:magick)

      Dir.mktmpdir do |directory|
        destination = File.join(directory, "output.png")

        expect {
          described_class.downsize(
            source,
            destination,
            "50%",
            filename: "favicon.ico",
            raise_on_error: true,
          )
        }.to raise_error(DiscourseVips::InvalidImage, "unsupported input format")
        expect(ImageMagick).not_to have_received(:magick)
        expect(File).not_to exist(destination)
      end
    end
  end
end
