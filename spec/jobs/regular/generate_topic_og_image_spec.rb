# frozen_string_literal: true

RSpec.describe Jobs::GenerateTopicOgImage do
  fab!(:topic)

  before { SiteSetting.generate_topic_og_image = true }

  it "does nothing when the setting is disabled" do
    SiteSetting.generate_topic_og_image = false
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
  end

  it "does nothing when topic has a user-uploaded image" do
    topic.update_column(:image_upload_id, Fabricate(:upload).id)
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
  end

  it "does nothing when topic already has a generated OG image" do
    topic.custom_fields["og_image_upload_id"] = 123
    topic.save_custom_fields
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
  end

  it "generates an OG image for a topic without an image" do
    upload = Fabricate(:upload)
    TopicOgImageGenerator.any_instance.expects(:generate).returns(upload)
    described_class.new.execute(topic_id: topic.id)
    expect(topic.reload.custom_fields["og_image_upload_id"].to_i).to eq(upload.id)
  end
end
