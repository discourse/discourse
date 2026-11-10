# frozen_string_literal: true

RSpec.describe Jobs::BackfillCategoryUploadSecurity do
  it "secures stale uploads only in read-restricted categories" do
    setup_s3
    SiteSetting.secure_uploads = true
    Jobs.run_immediately!

    private_category = Fabricate(:private_category, group: Fabricate(:group))
    owned_topic = Fabricate(:topic, category: private_category)
    owned_post = Fabricate(:post, topic: owned_topic)
    owned_upload = Fabricate(:upload_s3, access_control_post: owned_post)
    UploadReference.create!(upload: owned_upload, target: owned_post)
    owned_post.trash!
    owned_topic.trash!

    unowned_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))
    unowned_upload = Fabricate(:upload_s3)
    UploadReference.create!(upload: unowned_upload, target: unowned_post)
    unowned_post.trash!

    public_post = Fabricate(:post, topic: Fabricate(:topic, category: Fabricate(:category)))
    public_upload = Fabricate(:upload_s3, access_control_post: public_post)
    UploadReference.create!(upload: public_upload, target: public_post)

    stub_upload(owned_upload)
    stub_upload(unowned_upload)

    described_class.new.execute_onceoff(nil)

    expect(
      [owned_upload.reload.secure, unowned_upload.reload.secure, public_upload.reload.secure],
    ).to eq([true, true, false])
  end
end
