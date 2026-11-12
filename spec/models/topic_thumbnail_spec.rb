# frozen_string_literal: true
RSpec.describe "TopicThumbnail" do
  let(:upload1) { Fabricate(:image_upload, width: 50, height: 50) }
  let(:topic) { Fabricate(:topic, image_upload: upload1) }
  let(:upload2) { Fabricate(:image_upload, width: 50, height: 50) }
  let(:topic2) { Fabricate(:topic, image_upload: upload2) }
  let(:upload3) { Fabricate(:upload_no_dimensions) }
  let(:topic3) { Fabricate(:topic, image_upload: upload3) }

  before do
    SiteSetting.create_thumbnails = true

    Topic.stubs(:thumbnail_sizes).returns([[49, 49]])

    topic.generate_thumbnails!(extra_sizes: nil)

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(1)
  end

  it "does not enqueue job if original image is too large" do
    upload2.filesize = SiteSetting.max_image_size_kb.kilobytes + 1
    SiteSetting.create_thumbnails = true
    topic2.generate_thumbnails!(extra_sizes: nil)

    TopicThumbnail.ensure_consistency!
    topic2.reload

    expect(topic2.topic_thumbnails.length).to eq(0)
    expect(Jobs::GenerateTopicThumbnails.jobs.size).to eq(0)
  end

  it "does not enqueue job if image_upload width is nil" do
    SiteSetting.create_thumbnails = true
    topic3.image_url(enqueue_if_missing: true)

    TopicThumbnail.ensure_consistency!
    topic3.reload

    expect(topic3.topic_thumbnails.length).to eq(0)
    expect(Jobs::GenerateTopicThumbnails.jobs.size).to eq(0)
  end

  it "cleans up deleted uploads" do
    upload1.delete

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(0)
  end

  it "cleans up deleted optimized images" do
    upload1.optimized_images.reload.delete_all

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(0)
  end

  it "skips optimized image creation for animated uploads when setting is enabled" do
    SiteSetting.animated_topic_thumbnails = true
    animated_upload = Fabricate(:image_upload, width: 50, height: 50, animated: true)

    thumbnail = TopicThumbnail.find_or_create_for!(animated_upload, max_width: 49, max_height: 49)

    expect(thumbnail).to be_present
    expect(thumbnail.optimized_image_id).to be_nil
  end

  it "creates optimized image for animated uploads when setting is disabled" do
    SiteSetting.animated_topic_thumbnails = false
    animated_upload = Fabricate(:image_upload, width: 50, height: 50, animated: true)

    thumbnail = TopicThumbnail.find_or_create_for!(animated_upload, max_width: 49, max_height: 49)

    expect(thumbnail).to be_present
    expect(thumbnail.optimized_image_id).to be_present
  end

  it "cleans up unneeded sizes" do
    expect(topic.topic_thumbnails.length).to eq(1)
    topic.topic_thumbnails[0].update_column(:max_width, 999_999)

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(0)
  end
end
