# frozen_string_literal: true
require 'rails_helper'

describe "TopicThumbnail" do
  let(:upload1) { Fabricate(:image_upload, width: 5000, height: 5000) }
  let(:topic) { Fabricate(:topic, image_upload: upload1) }

  before do
    SiteSetting.create_thumbnails = true
    topic.generate_thumbnails!

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(1)
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

  it "cleans up unneeded sizes" do
    expect(topic.topic_thumbnails.length).to eq(1)
    topic.topic_thumbnails[0].update_column(:max_width, 999999)

    TopicThumbnail.ensure_consistency!
    topic.reload

    expect(topic.topic_thumbnails.length).to eq(0)
  end

end
