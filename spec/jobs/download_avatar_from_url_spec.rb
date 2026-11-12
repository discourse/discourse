# frozen_string_literal: true

RSpec.describe Jobs::DownloadAvatarFromUrl do
  fab!(:user)

  context "with an associated account avatar" do
    let(:url) { "https://avatars.example.com/avatar.png" }
    let(:account) do
      Fabricate(
        :user_associated_account,
        user: user,
        provider_name: "google_oauth2",
        info: {
          image: url,
        },
      )
    end
    let(:upload) { Fabricate(:upload, user: user) }

    before do
      SiteSetting.google_oauth2_client_id = "client"
      SiteSetting.google_oauth2_client_secret = "secret"
      SiteSetting.enable_google_oauth2_logins = true
      stub_request(:get, url).to_return(body: file_from_fixtures("logo.png"))
      user.user_avatar.update!(custom_upload: upload)
      user.update!(uploaded_avatar_id: upload.id)
    end

    it "retains the provider image separately without changing the chosen upload" do
      described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)

      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
      expect(user.user_avatar.reload.custom_upload_id).to eq(upload.id)
      expect(account.reload.avatar_upload_id).to be_present
      expect(UploadReference.where(target: account).pluck(:upload_id)).to eq(
        [account.avatar_upload_id],
      )
    end

    it "updates the selected provider without replacing the custom upload" do
      user.user_avatar.update!(selected_user_associated_account_id: account.id)

      described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)

      expect(user.reload.uploaded_avatar_id).to eq(account.reload.avatar_upload_id)
      expect(user.user_avatar.reload.custom_upload_id).to eq(upload.id)
    end

    it "ignores downloads queued before an account was disconnected" do
      account_id = account.id
      account.destroy!

      expect {
        described_class.new.execute(url: url, user_id: user.id, associated_account_id: account_id)
      }.not_to change(Upload, :count)
      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
    end

    it "ignores downloads queued for a previous image URL or another user" do
      account.update!(info: { image: "https://avatars.example.com/new.png" })

      expect {
        described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)
      }.not_to change(Upload, :count)

      account.update!(info: { image: url }, user: Fabricate(:user))

      expect {
        described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)
      }.not_to change(Upload, :count)
    end

    it "keeps the previous provider image when downloading fails" do
      account.update!(avatar_upload: upload)
      user.user_avatar.update!(selected_user_associated_account_id: account.id)
      stub_request(:get, url).to_return(status: Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found])

      described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)

      expect(account.reload.avatar_upload_id).to eq(upload.id)
      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
    end

    it "preserves a choice made while the provider image is downloading" do
      user.user_avatar.update!(selected_user_associated_account_id: account.id)
      stub_request(:get, url).to_return do
        user.user_avatar.update!(selected_user_associated_account_id: nil)
        { body: File.binread(file_from_fixtures("logo.png")) }
      end

      described_class.new.execute(url: url, user_id: user.id, associated_account_id: account.id)

      expect(account.reload.avatar_upload_id).to be_present
      expect(user.reload.uploaded_avatar_id).to eq(upload.id)
      expect(user.user_avatar.selected_user_associated_account_id).to be_nil
    end
  end

  it "ignores non-HTTP avatar URLs" do
    expect do
      described_class.new.execute(url: "/assets/something/nice.jpg", user_id: user.id)
    end.to_not raise_error
  end
end
