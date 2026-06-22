# frozen_string_literal: true

require "tmpdir"

RSpec.describe DiscourseImage do
  describe ".downsize" do
    it "supports in-place transformations" do
      Dir.mktmpdir do |directory|
        image_path = File.join(directory, "image.png")
        FileUtils.cp(Rails.root.join("spec/fixtures/images/2000x2000.png"), image_path)

        described_class.downsize(image_path, image_path, "10000@")

        expect(described_class.size(image_path)).to eq([100, 100])
      end
    end
  end

  describe ".fix_orientation" do
    it "supports in-place transformations" do
      Dir.mktmpdir do |directory|
        image_path = File.join(directory, "image.jpg")
        FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.jpg"), image_path)

        described_class.fix_orientation(image_path)

        expect(described_class.size(image_path)).to eq([512, 512])
      end
    end
  end

  describe ".optimize_image!" do
    it "supports in-place optimization" do
      Dir.mktmpdir do |directory|
        image_path = File.join(directory, "image.png")
        FileUtils.cp(Rails.root.join("spec/fixtures/images/pngquant.png"), image_path)

        described_class.optimize_image!(image_path, allow_lossy_png: true, strict: false)

        expect(described_class.size(image_path)).to eq([261, 227])
      end
    end
  end

  describe ".size" do
    it "works when an image path has a symlinked parent directory" do
      Dir.mktmpdir do |directory|
        real_directory = File.join(directory, "real")
        symlink_directory = File.join(directory, "linked")
        FileUtils.mkdir_p(real_directory)
        FileUtils.ln_s(real_directory, symlink_directory)

        image_path = File.join(real_directory, "logo.png")
        FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), image_path)

        expect(described_class.size(File.join(symlink_directory, "logo.png"))).to eq([244, 66])
      end
    end
  end
end
