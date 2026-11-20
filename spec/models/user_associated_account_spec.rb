# frozen_string_literal: true
RSpec.describe UserAssociatedAccount do
  fab!(:user)
  fab!(:provider_upload) { Fabricate(:upload, user: user) }
  fab!(:account) do
    Fabricate(:user_associated_account, user: user, avatar_upload_id: provider_upload.id)
  end

  describe "#destroy!" do
    it "keeps the current picture and custom upload while removing the selected provider" do
      custom_upload = Fabricate(:upload, user: user)
      user.update!(uploaded_avatar_id: provider_upload.id)
      user.user_avatar.update!(
        custom_upload_id: custom_upload.id,
        selected_user_associated_account_id: account.id,
      )

      account.destroy!

      expect(user.reload.uploaded_avatar_id).to eq(provider_upload.id)
      expect(user.user_avatar.custom_upload_id).to eq(custom_upload.id)
      expect(user.user_avatar.selected_user_associated_account_id).to eq(nil)
      expect(
        UploadReference.where(upload_id: provider_upload.id).pluck(:target_type, :target_id),
      ).to eq([["User", user.id]])
    end
  end

  it "clears the provider source when its uploaded image is deleted" do
    user.update!(uploaded_avatar_id: provider_upload.id)
    user.user_avatar.update!(selected_user_associated_account_id: account.id)

    provider_upload.destroy!

    expect(account.reload.avatar_upload_id).to be_nil
    expect(user.reload.uploaded_avatar_id).to be_nil
    expect(user.user_avatar.selected_user_associated_account_id).to be_nil
    expect(UploadReference.where(target: account)).not_to exist
  end

  describe "#update!" do
    it "stops following the provider when the account moves to another user" do
      new_user = Fabricate(:user)
      user.update!(uploaded_avatar_id: provider_upload.id)
      user.user_avatar.update!(selected_user_associated_account_id: account.id)

      account.update!(user: new_user)

      expect(user.reload.uploaded_avatar_id).to eq(provider_upload.id)
      expect(user.user_avatar.selected_user_associated_account_id).to eq(nil)
      expect(new_user.reload.uploaded_avatar_id).to eq(nil)
      expect(UploadReference.where(target: account).pluck(:upload_id)).to eq([provider_upload.id])
    end
  end

  describe ".cleanup!" do
    it "removes orphaned account image references while preserving connected accounts" do
      orphaned_account =
        Fabricate(:user_associated_account, avatar_upload_id: Fabricate(:upload).id)
      orphaned_account.update_columns(user_id: nil, updated_at: 2.days.ago)

      described_class.cleanup!

      expect(described_class.exists?(orphaned_account.id)).to eq(false)
      expect(UploadReference.where(target: orphaned_account)).to be_empty
      expect(described_class.exists?(account.id)).to eq(true)
      expect(UploadReference.where(target: account).pluck(:upload_id)).to eq([provider_upload.id])
    end
  end
end
