# frozen_string_literal: true

describe UserAvatarUpdater do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  describe ".update" do
    it "updates the selected and custom avatar together" do
      upload = Fabricate(:upload, user:)
      described_class.update(user.guardian, user, upload)
      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
      expect(user.user_avatar.reload.custom_upload_id).to eq(upload.id)
    end

    it "clears the associated account selection when choosing a custom avatar" do
      account = Fabricate(:user_associated_account, user:)
      user.user_avatar.update!(selected_user_associated_account_id: account.id)
      upload = Fabricate(:upload, user:)

      described_class.update(user.guardian, user, upload)

      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
      expect(user.user_avatar.reload.selected_user_associated_account_id).to be_nil
    end

    it "rejects updates to another user's avatar" do
      other_user = Fabricate(:user)
      upload = Fabricate(:upload, user:)
      expect do described_class.update(user.guardian, other_user, upload) end.to raise_error(
        Discourse::InvalidAccess,
      )
      expect(other_user.reload.uploaded_avatar_id).to be_nil
    end

    it "rejects an upload the actor cannot pick" do
      upload = Fabricate(:upload)
      expect do described_class.update(user.guardian, user, upload) end.to raise_error(
        Discourse::InvalidAccess,
      )
      expect(user.reload.uploaded_avatar_id).to be_nil
    end
  end
end
