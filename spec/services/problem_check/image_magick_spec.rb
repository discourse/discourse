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

        it { expect(check.call).to be_empty }
      end

      context "when Image Magick is not installed" do
        let(:installed) { false }

        it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
      end
    end

    context "when thumbnail creation is disabled" do
      let(:enabled) { false }
      let(:installed) { false }

      it { expect(check.call).to be_empty }
    end
  end
end
