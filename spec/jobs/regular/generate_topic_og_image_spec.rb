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
    topic.update_column(:og_image_upload_id, Fabricate(:upload).id)
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
  end

  it "does nothing for personal messages" do
    pm = Fabricate(:private_message_topic)
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: pm.id)
    expect(pm.reload.og_image_upload_id).to be_nil
  end

  it "does nothing for topics in a read-restricted category" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    topic.update!(category: private_category)
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
    expect(topic.reload.og_image_upload_id).to be_nil
  end

  it "generates an OG image for a topic without an image" do
    upload = Fabricate(:upload)
    TopicOgImageGenerator.any_instance.expects(:generate).returns(upload)
    described_class.new.execute(topic_id: topic.id)
    topic.reload
    expect(topic.og_image_upload_id).to eq(upload.id)
    expect(UploadReference.exists?(upload_id: upload.id, target: topic)).to eq(true)
  end
end
