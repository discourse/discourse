# frozen_string_literal: true

RSpec.describe ProblemCheck::ImageMagick do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      SiteSetting.stubs(create_thumbnails: enabled)
      if safe_image_config == :not_configured
        SafeImage.stubs(:config).raises(SafeImage::NotConfiguredError)
      else
        SafeImage.stubs(:config).returns(safe_image_config)
      end
    end

    context "when thumbnail creation is enabled" do
      let(:enabled) { true }

      context "when Safe Image is configured" do
        let(:safe_image_config) do
          SafeImage::Config.new(
            backend: :vips,
            landlock: false,
            max_pixels: SafeImage::DEFAULT_MAX_PIXELS,
          )
        end

        it { expect(check).to be_chill_about_it }
      end

      context "when Safe Image is not configured" do
        let(:safe_image_config) { :not_configured }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            'The server is configured to create thumbnails of large images, but ImageMagick is not installed. Install ImageMagick using your favorite package manager or <a href="https://www.imagemagick.org/script/download.php" target="_blank">download the latest release</a>.',
          )
        end
      end
    end

    context "when thumbnail creation is disabled" do
      let(:enabled) { false }
      let(:safe_image_config) { :not_configured }

      it { expect(check).to be_chill_about_it }
    end
  end
end
