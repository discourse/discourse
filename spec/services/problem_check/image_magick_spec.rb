# frozen_string_literal: true

RSpec.describe ProblemCheck::ImageMagick do
  subject(:check) { described_class.new }

  describe ".call" do
    before do
      SiteSetting.stubs(create_thumbnails: enabled)
      Kernel.stubs(system: installed)
    end

    context "when thumbnail creation is enabled" do
      let(:enabled) { true }

      context "when Image Magick is installed" do
        let(:installed) { true }

        it { expect(check).to be_chill_about_it }
      end

      context "when Image Magick is not installed" do
        let(:installed) { false }

        it do
          expect(check).to have_a_problem.with_priority("low").with_message(
            'The server is configured to create thumbnails of large images, but ImageMagick is not installed. Install ImageMagick using your favorite package manager or <a href="https://www.imagemagick.org/script/download.php" target="_blank">download the latest release</a>.',
          )
        end
      end
    end

    context "when thumbnail creation is disabled" do
      let(:enabled) { false }
      let(:installed) { false }

      it { expect(check).to be_chill_about_it }
    end
  end
end
