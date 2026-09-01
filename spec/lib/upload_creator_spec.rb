# frozen_string_literal: true

require "file_store/s3_store"

RSpec.describe UploadCreator do
  fab!(:user)
  fab!(:admin)

  describe "svg sizes expressed in units other than pixels" do
    let(:tiny_svg_filename) { "tiny.svg" }
    let(:tiny_svg_file) { file_from_fixtures(tiny_svg_filename) }

    let(:massive_svg_filename) { "massive.svg" }
    let(:massive_svg_file) { file_from_fixtures(massive_svg_filename) }

    let(:zero_sized_svg_filename) { "zero_sized.svg" }
    let(:zero_sized_svg_file) { file_from_fixtures(zero_sized_svg_filename) }

    it "is viewable when a dimension is a fraction of a unit" do
      upload =
        UploadCreator.new(tiny_svg_file, tiny_svg_filename, force_optimize: true).create_for(
          user.id,
        )

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "is not larger than the maximum thumbnail size" do
      upload =
        UploadCreator.new(massive_svg_file, massive_svg_filename, force_optimize: true).create_for(
          user.id,
        )

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end

    it "handles zero dimension files" do
      upload =
        UploadCreator.new(
          zero_sized_svg_file,
          zero_sized_svg_filename,
          force_optimize: true,
        ).create_for(user.id)

      expect(upload.width).to be > 50
      expect(upload.height).to be > 50

      expect(upload.thumbnail_width).to be <= SiteSetting.max_image_width
      expect(upload.thumbnail_height).to be <= SiteSetting.max_image_height
    end
  end

  describe "#should_downsize?" do
    context "with GIF image" do
      let(:gif_file) { file_from_fixtures("animated.gif") }

      before { SiteSetting.max_image_size_kb = 1 }

      it "is not downsized" do
        creator = UploadCreator.new(gif_file, "animated.gif")
        creator.extract_image_info!
        expect(creator.should_downsize?).to eq(false)
      end
    end
  end

  describe "before_upload_creation event" do
    let(:filename) { "logo.jpg" }
    let(:file) { file_from_fixtures(filename) }

    before do
      setup_s3
      stub_s3_store
    end

    it "does not save the upload if an event added errors to the upload" do
      error = "This upload is invalid"

      event = Proc.new { |file, is_image, upload| upload.errors.add(:base, error) }

      DiscourseEvent.on(:before_upload_creation, &event)

      created_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(created_upload.persisted?).to eq(false)
      expect(created_upload.errors).to contain_exactly(error)
      DiscourseEvent.off(:before_upload_creation, &event)
    end
  end
end
