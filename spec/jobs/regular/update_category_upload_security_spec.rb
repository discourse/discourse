# frozen_string_literal: true

RSpec.describe Jobs::UpdateCategoryUploadSecurity do
  it "updates upload security for soft-deleted topics and posts in the category" do
    setup_s3
    SiteSetting.secure_uploads = true
    Jobs.run_immediately!
    category = Fabricate(:private_category, group: Fabricate(:group))
    topic = Fabricate(:topic, category: category)
    post = Fabricate(:post, topic: topic)
    upload = Fabricate(:upload_s3, access_control_post: post)
    UploadReference.create!(upload: upload, target: post)
    post.trash!
    topic.trash!
    stub_upload(upload)

    described_class.new.execute(category_id: category.id)

    expect(upload.reload.secure).to eq(true)
  end
end
