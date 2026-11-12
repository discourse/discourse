# frozen_string_literal: true

RSpec.describe Jobs::GenerateTopicOgImage do
  fab!(:topic)

  before { SiteSetting.generate_topic_og_image = true }

  it "does nothing when the setting is disabled" do
    SiteSetting.generate_topic_og_image = false
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
  end

  it "does nothing when login_required is enabled" do
    SiteSetting.login_required = true
    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)
    expect(topic.reload.og_image_upload_id).to be_nil
  end

  xit "clears stale generated OG images when topic has a user-uploaded image" do
    old_upload = Fabricate(:upload)
    topic.update_column(:image_upload_id, Fabricate(:upload).id)
    topic.update_column(:og_image_upload_id, old_upload.id)
    UploadReference.ensure_exist!(upload_ids: [old_upload.id], target: topic)

    TopicOgImageGenerator.any_instance.expects(:generate).never
    described_class.new.execute(topic_id: topic.id)

    expect(topic.reload.og_image_upload_id).to be_nil
    expect(UploadReference.exists?(upload_id: old_upload.id, target: topic)).to eq(false)
  end

  xit "replaces an existing generated OG image and cleans up the old reference" do
    old_upload = Fabricate(:upload)
    topic.update_column(:og_image_upload_id, old_upload.id)
    UploadReference.ensure_exist!(upload_ids: [old_upload.id], target: topic)

    new_upload = Fabricate(:upload)
    TopicOgImageGenerator.any_instance.expects(:generate).returns(new_upload)

    described_class.new.execute(topic_id: topic.id)

    expect(topic.reload.og_image_upload_id).to eq(new_upload.id)
    expect(UploadReference.exists?(upload_id: new_upload.id, target: topic)).to eq(true)
    expect(UploadReference.exists?(upload_id: old_upload.id, target: topic)).to eq(false)
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

  xit "generates an OG image for a topic without an image" do
    upload = Fabricate(:upload)
    TopicOgImageGenerator.any_instance.expects(:generate).returns(upload)
    described_class.new.execute(topic_id: topic.id)
    topic.reload
    expect(topic.og_image_upload_id).to eq(upload.id)
    expect(UploadReference.exists?(upload_id: upload.id, target: topic)).to eq(true)
  end
end
