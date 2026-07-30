# frozen_string_literal: true

RSpec.describe Upload do
  before { SiteSetting.use_vips_for_image_processing = true }

  describe "#fix_dimensions!" do
    it "repairs stored SVG dimensions without ImageMagick" do
      ImageMagick.expects(:identify).never
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
    it "uses the requested target without probing the source through ImageMagick" do
      ImageMagick.expects(:identify).never

      Dir.mktmpdir("upload-jpeg-quality") do |directory|
        source = Rails.root.join("spec/fixtures/images/logo.jpg").to_s
        path = File.join(directory, "quality.jpg")
        Vips.call("copy", source, "#{path}[Q=62]", read: [source], write: [directory])
        upload = described_class.new

        expect(
          {
            lower_target: upload.target_image_quality(path, 50),
            higher_target: upload.target_image_quality(path, 70),
          },
        ).to eq(lower_target: 50, higher_target: 70)
      end
    end

    it "preserves the existing malformed-input behavior without fallback" do
      ImageMagick.expects(:identify).never

      Dir.mktmpdir("upload-jpeg-quality") do |directory|
        path = File.join(directory, "malformed.jpg")
        File.binwrite(path, "not a jpeg")

        expect(described_class.new.target_image_quality(path, 70)).to eq(70)
      end
    end
  end
end
