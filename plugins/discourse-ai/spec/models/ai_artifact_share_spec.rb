# frozen_string_literal: true

RSpec.describe AiArtifactShare do
  fab!(:artifact, :ai_artifact)
  fab!(:owner, :user)

  before { enable_current_plugin }

  it "removes published snapshots when the source artifact is destroyed" do
    share =
      described_class.create!(
        ai_artifact: artifact,
        user: owner,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )

    artifact.destroy!

    expect(described_class.exists?(share.id)).to eq(false)
  end

  it "removes only the destroyed owner's published snapshots" do
    share =
      described_class.create!(
        ai_artifact: artifact,
        user: owner,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )
    other_share =
      described_class.create!(
        ai_artifact: artifact,
        user: artifact.user,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )

    UserDestroyer.new(Discourse.system_user).destroy(owner)

    expect(described_class.where(id: [share.id, other_share.id]).pluck(:id)).to eq([other_share.id])
  end

  it "deletes share storage when the source artifact is hard-destroyed" do
    share =
      described_class.create!(
        ai_artifact: artifact,
        user: owner,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )
    record = share.key_values.create!(user: owner, key: "vote", value: "yes")

    artifact.destroy!

    expect(AiArtifactShareKeyValue.exists?(record.id)).to eq(false)
  end

  it "removes a deleted user's source artifact storage while preserving other users' values" do
    deleted_record = artifact.key_values.create!(user: owner, key: "vote", value: "deleted")
    surviving_record =
      artifact.key_values.create!(user: artifact.user, key: "vote", value: "survives")

    UserDestroyer.new(Discourse.system_user).destroy(owner)

    expect(AiArtifactKeyValue.where(id: [deleted_record.id, surviving_record.id]).pluck(:id)).to eq(
      [surviving_record.id],
    )
  end

  it "cleans up both an owner's share storage and their votes on other shares" do
    share =
      described_class.create!(
        ai_artifact: artifact,
        user: owner,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )
    other_share =
      described_class.create!(
        ai_artifact: artifact,
        user: artifact.user,
        **described_class.new(ai_artifact: artifact).snapshot_attributes(version_number: 0),
      )
    visitor = Fabricate(:user)
    owned_record = share.key_values.create!(user: visitor, key: "vote", value: "owned")
    visitor_record = other_share.key_values.create!(user: owner, key: "vote", value: "visitor")
    surviving_record = other_share.key_values.create!(user: visitor, key: "vote", value: "survives")

    UserDestroyer.new(Discourse.system_user).destroy(owner)

    expect(
      AiArtifactShareKeyValue.where(
        id: [owned_record.id, visitor_record.id, surviving_record.id],
      ).pluck(:id),
    ).to eq([surviving_record.id])
  end
end
