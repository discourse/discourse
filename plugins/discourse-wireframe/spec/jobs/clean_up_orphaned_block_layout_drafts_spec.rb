# frozen_string_literal: true

RSpec.describe Jobs::CleanUpOrphanedBlockLayoutDrafts do
  fab!(:user)
  fab!(:theme)

  def draft_for(user_id:, theme_id:)
    DiscourseWireframe::BlockLayoutDraft.create!(
      user_id:,
      theme_id:,
      outlet: "homepage-blocks",
      data: "{}",
    )
  end

  before { SiteSetting.wireframe_enabled = true }

  it "destroys drafts whose owning user no longer exists" do
    ghost_user_id = (User.maximum(:id) || 0) + 9999
    orphan = draft_for(user_id: ghost_user_id, theme_id: theme.id)

    described_class.new.execute(nil)

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: orphan.id)).not_to exist
  end

  it "destroys drafts whose owning theme no longer exists" do
    ghost_theme_id = (Theme.maximum(:id) || 0) + 9999
    orphan = draft_for(user_id: user.id, theme_id: ghost_theme_id)

    described_class.new.execute(nil)

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: orphan.id)).not_to exist
  end

  it "prunes the orphaned draft's UploadReferences" do
    upload = Fabricate(:upload)
    ghost_theme_id = (Theme.maximum(:id) || 0) + 9999
    DiscourseWireframe::BlockLayoutDraft.create!(
      user_id: user.id,
      theme_id: ghost_theme_id,
      outlet: "homepage-blocks",
      data: {
        "layout" => [
          { "args" => { "image" => { "source" => "upload", "upload_id" => upload.id } } },
        ],
      }.to_json,
    )
    expect(UploadReference.where(upload_id: upload.id)).to exist

    described_class.new.execute(nil)

    expect(UploadReference.where(upload_id: upload.id)).not_to exist
  end

  it "leaves drafts with a live owner untouched" do
    live = draft_for(user_id: user.id, theme_id: theme.id)

    described_class.new.execute(nil)

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: live.id)).to exist
  end

  it "does nothing when the plugin is disabled" do
    SiteSetting.wireframe_enabled = false
    ghost_theme_id = (Theme.maximum(:id) || 0) + 9999
    orphan = draft_for(user_id: user.id, theme_id: ghost_theme_id)

    described_class.new.execute(nil)

    expect(DiscourseWireframe::BlockLayoutDraft.where(id: orphan.id)).to exist
  end
end
