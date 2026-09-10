# frozen_string_literal: true

RSpec.describe "Block-layout draft upload cascade" do
  fab!(:user)
  fab!(:theme)
  fab!(:upload)

  def create_draft(user_id: user.id, theme_id: theme.id)
    DiscourseWireframe::BlockLayoutDraft.create!(
      user_id:,
      theme_id:,
      outlet: "homepage-blocks",
      data: {
        "layout" => [
          { "args" => { "image" => { "source" => "upload", "upload_id" => upload.id } } },
        ],
      }.to_json,
    )
  end

  it "protects a draft-only upload from CleanUpUploads, then frees it once the draft is gone" do
    SiteSetting.clean_up_uploads = true
    SiteSetting.clean_orphan_uploads_grace_period_hours = 1

    draft = create_draft
    upload.update!(created_at: 2.hours.ago, updated_at: 2.hours.ago)

    # The draft's UploadReference exempts the upload from the cleanup job.
    Jobs::CleanUpUploads.new.reset_last_cleanup!
    Jobs::CleanUpUploads.new.execute(nil)
    expect(Upload.exists?(upload.id)).to eq(true)

    # Once the draft is destroyed, the reference is pruned and the upload is collectable.
    draft.destroy!
    expect(UploadReference.where(upload_id: upload.id)).not_to exist

    Jobs::CleanUpUploads.new.reset_last_cleanup!
    Jobs::CleanUpUploads.new.execute(nil)
    expect(Upload.exists?(upload.id)).to eq(false)
  end

  it "cascades cleanup when the owning user is destroyed (while enabled)" do
    SiteSetting.wireframe_enabled = true
    draft = create_draft
    expect(UploadReference.where(upload_id: upload.id)).to exist

    UserDestroyer.new(Discourse.system_user).destroy(user)

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: draft.id)).not_to exist
    expect(UploadReference.where(upload_id: upload.id)).not_to exist
  end

  it "cascades cleanup when the owning theme is destroyed (while enabled)" do
    SiteSetting.wireframe_enabled = true
    draft = create_draft
    expect(UploadReference.where(upload_id: upload.id)).to exist

    theme.destroy!

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: draft.id)).not_to exist
    expect(UploadReference.where(upload_id: upload.id)).not_to exist
  end
end
