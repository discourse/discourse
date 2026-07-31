# frozen_string_literal: true

RSpec.describe Upload do
  before { SiteSetting.use_vips_for_image_processing = true }

  describe "#fix_dimensions!" do
    it "repairs stored SVG dimensions" do
      upload =
        UploadCreator.new(
          file_from_fixtures("tiny.svg"),
          "tiny.svg",
          force_optimize: true,
        ).create_for(Discourse.system_user.id)
      upload.update_columns(width: nil, height: nil, thumbnail_width: nil, thumbnail_height: nil)

      upload.fix_dimensions!

      expect(
        {
          dimensions: [upload.width, upload.height],
          thumbnail_dimensions: [upload.thumbnail_width, upload.thumbnail_height],
        },
      ).to eq(dimensions: [115, 86], thumbnail_dimensions: [115, 86])
    end
  end

  describe "#target_image_quality" do
    it "recompresses only when the estimated source quality exceeds the target" do
      Dir.mktmpdir("upload-jpeg-quality") do |directory|
        source = Rails.root.join("spec/fixtures/images/logo.jpg").to_s
        low_quality = File.join(directory, "low-quality.jpg")
        high_quality = File.join(directory, "high-quality.jpg")
        [[low_quality, 50], [high_quality, 90]].each do |path, quality|
          Vips.run(
            "vips",
            "copy",
            source,
            "#{path}[Q=#{quality}]",
            read: [source],
            write: [directory],
          )
        end

        expect(
          {
            lower_source_quality: described_class.new.target_image_quality(low_quality, 70),
            higher_source_quality: described_class.new.target_image_quality(high_quality, 70),
          },
        ).to eq(lower_source_quality: nil, higher_source_quality: 70)
      end
    end

    it "preserves the existing malformed-input behavior" do
      Dir.mktmpdir("upload-jpeg-quality") do |directory|
        path = File.join(directory, "malformed.jpg")
        File.binwrite(path, "not a jpeg")

        expect(described_class.new.target_image_quality(path, 70)).to eq(70)
      end
    end

    it "uses the configured target when jhead returns no quality estimate" do
      Vips.stubs(:run).returns("File name : image.jpg\n")

      expect(described_class.new.target_image_quality("image.jpg", 70)).to eq(70)
    end
  end
end
