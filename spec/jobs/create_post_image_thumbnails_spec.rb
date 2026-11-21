# frozen_string_literal: true

RSpec.describe Jobs::CreatePostImageThumbnails do
  fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000, dominant_color: nil) }
  fab!(:post) { Fabricate(:post, raw: "<img src=\"#{upload.url}\">") }

  before { SiteSetting.create_thumbnails = true }

  it "creates the thumbnails and dominant color, then re-runs post processing without deferral" do
    expect_enqueued_with(
      job: :process_post,
      args: {
        post_id: post.id,
        cooking_options: {
          topic_id: post.topic_id,
        },
        defer_thumbnails: false,
        bypass_bump: true,
        skip_pull_hotlinked_images: true,
      },
    ) do
      described_class.new.execute(
        post_id: post.id,
        cooking_options: {
          topic_id: post.topic_id,
        },
        thumbnails: [
          { upload_id: upload.id, width: 690, height: 788, crop: false },
          { upload_id: -1, width: 690, height: 788, crop: false },
        ],
      )
    end

    expect(upload.thumbnail(690, 788)).to be_present
    expect(upload.reload.dominant_color).to eq("FFFFFF")
  end

  it "does nothing when the post is gone" do
    expect_not_enqueued_with(job: :process_post) do
      described_class.new.execute(
        post_id: -1,
        thumbnails: [{ upload_id: upload.id, width: 690, height: 788, crop: false }],
      )
    end

    expect(upload.thumbnail(690, 788)).to be_nil
  end
end
