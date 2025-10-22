# frozen_string_literal: true

RSpec.describe OptimizedVideo do
  before(:each) do
    # Add video extensions to authorized extensions
    extensions = SiteSetting.authorized_extensions.split("|")
    SiteSetting.authorized_extensions = (extensions | %w[mp4 mov avi mkv]).join("|")
  end

  describe ".create_for" do
    let(:options) do
      {
        filesize: 1024,
        sha1: "test-sha1-hash",
        url: "//bucket.s3.region.amazonaws.com/original/1X/test.mp4",
        extension: "mp4",
        adapter: "aws_mediaconvert",
      }
    end

    it "returns nil if upload is blank" do
      expect(OptimizedVideo.create_for(nil, "test.mp4", 1, options)).to be_nil
    end

    it "creates an optimized video record with associated upload" do
      # Create upload manually without fabricators
      user = User.create!(username: "testuser", email: "test@example.com")
      upload =
        Upload.create!(
          user: user,
          original_filename: "original.mp4",
          filesize: 2048,
          sha1: "original-sha1",
          extension: "mp4",
          url: "//bucket.s3.region.amazonaws.com/original.mp4",
        )

      expect { OptimizedVideo.create_for(upload, "test.mp4", upload.user_id, options) }.to change {
        Upload.count
      }.by(1).and change { OptimizedVideo.count }.by(1)

      optimized_video = OptimizedVideo.last
      optimized_upload = optimized_video.optimized_upload

      expect(optimized_video.upload).to eq(upload)
      expect(optimized_video.adapter).to eq("aws_mediaconvert")
      expect(optimized_upload.filesize).to eq(1024)
      expect(optimized_upload.sha1).to eq("test-sha1-hash")
      expect(optimized_upload.url).to eq("//bucket.s3.region.amazonaws.com/original/1X/test.mp4")
      expect(optimized_upload.extension).to eq("mp4")
    end
  end

  describe "#destroy" do
    it "should destroy the optimized video and its associated upload" do
      optimized_video = Fabricate(:optimized_video)
      expect { optimized_video.destroy }.to change(OptimizedVideo, :count).by(-1)
      expect(Upload.exists?(optimized_video.optimized_upload_id)).to be(false)
    end
  end
end
