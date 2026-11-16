# frozen_string_literal: true

RSpec.describe UserAvatar do
  fab!(:user)
  let(:avatar) { user.user_avatar }

  describe "#update_gravatar!" do
    fab!(:upload) { Fabricate(:upload, user: user) }

    describe "when working" do
      before do
        stub_request(:get, %r{https://www.gravatar.com/avatar/}).to_return(
          body: File.binread(file_from_fixtures("logo.png")),
        )
      end

      it "downloads and retains Gravatar when uploads are disabled" do
        SiteSetting.authorized_extensions = ""
        freeze_time

        expect { avatar.update_gravatar! }.to change { Upload.count }.by(1)
        expect(avatar.gravatar_upload).to eq(Upload.last)
        expect(avatar.reload.last_gravatar_download_attempt).to eq_time(Time.now)
        expect(user.reload.uploaded_avatar).to eq(nil)

        expect do avatar.destroy end.to_not change { Upload.count }
      end

      it "preserves the selected provider when its picture also matches Gravatar" do
        account = Fabricate(:user_associated_account, user: user, avatar_upload_id: upload.id)
        user.update!(uploaded_avatar: upload)
        avatar.update!(gravatar_upload: upload, selected_user_associated_account_id: account.id)

        avatar.update_gravatar!

        expect(user.reload.uploaded_avatar_id).to eq(upload.id)
        expect(avatar.reload.gravatar_upload).to eq(Upload.last)
      end

      it "preserves the user's custom upload" do
        user.update!(uploaded_avatar: upload)

        avatar.update!(custom_upload: upload, gravatar_upload: Fabricate(:upload, user: user))

        avatar.update_gravatar!

        expect(user.reload.uploaded_avatar).to eq(upload)
        expect(avatar.reload.custom_upload).to eq(upload)
        expect(avatar.gravatar_upload).to eq(Upload.last)
      end

      it "updates the user's selected Gravatar" do
        user.update!(uploaded_avatar: upload)
        avatar.update!(gravatar_upload: upload)

        avatar.update_gravatar!

        expect(Upload.find_by(id: upload.id)).not_to eq(nil)

        new_upload = Upload.last

        expect(user.reload.uploaded_avatar).to eq(new_upload)
        expect(avatar.reload.gravatar_upload).to eq(new_upload)
      end
    end

    describe "when failing" do
      it "always update 'last_gravatar_download_attempt'" do
        freeze_time

        FileHelper.expects(:download).raises(SocketError)

        expect do expect { avatar.update_gravatar! }.to raise_error(SocketError) end.to_not change {
          Upload.count
        }

        expect(avatar.reload.last_gravatar_download_attempt).to eq_time(Time.now)
      end
    end

    describe "404 should be silent, nothing to do really" do
      it "does nothing when avatar is 404" do
        SecureRandom.stubs(:urlsafe_base64).returns("5555")
        freeze_time

        stub_request(
          :get,
          "https://www.gravatar.com/avatar/#{avatar.user.email_hash}.png?d=404&reset_cache=5555&s=#{Discourse.avatar_sizes.max}",
        ).to_return(status: 404, body: "", headers: {})

        expect do avatar.update_gravatar! end.to_not change { Upload.count }

        expect(avatar.reload.last_gravatar_download_attempt).to eq_time(Time.now)
      end
    end

    it "does not raise an error without a primary email" do
      avatar.user.primary_email.destroy
      avatar.user.reload

      # If raises an error, test fails
      avatar.update_gravatar!
    end
  end

  describe ".import_url_for_user" do
    it "clears provider selection when a forced import reuses a cached upload" do
      url = "https://example.com/avatar.png"
      stub_request(:get, url).to_return(body: File.binread(file_from_fixtures("logo.png")))
      described_class.import_url_for_user(url, user)

      account =
        Fabricate(:user_associated_account, user: user, avatar_upload_id: user.uploaded_avatar_id)
      avatar.update!(selected_user_associated_account_id: account.id)

      described_class.import_url_for_user(url, user, override_gravatar: false)

      expect(avatar.reload.selected_user_associated_account_id).to eq(account.id)

      described_class.import_url_for_user(url, user, override_gravatar: true)

      expect(avatar.reload.selected_user_associated_account_id).to be_nil
      expect(user.reload.uploaded_avatar_id).to eq(account.avatar_upload_id)
      expect(avatar.custom_upload_id).to eq(account.avatar_upload_id)

      custom_upload = Fabricate(:upload, user: user)
      avatar.update!(
        custom_upload: custom_upload,
        gravatar_upload_id: account.avatar_upload_id,
        selected_user_associated_account_id: account.id,
      )

      described_class.import_url_for_user(url, user, override_gravatar: true)

      expect(avatar.reload.selected_user_associated_account_id).to be_nil
      expect(avatar.custom_upload_id).to eq(custom_upload.id)
      expect(user.reload.uploaded_avatar_id).to eq(account.avatar_upload_id)
    end

    it "ignores a download when the account moves to another user before it completes" do
      new_user = Fabricate(:user)
      provider_upload = Fabricate(:upload, user: user)
      url = "https://example.com/avatar.png"
      account =
        Fabricate(
          :user_associated_account,
          user: user,
          avatar_upload: provider_upload,
          info: {
            image: url,
          },
        )
      user.update!(uploaded_avatar_id: provider_upload.id)
      avatar.update!(selected_user_associated_account_id: account.id)
      stub_request(:get, url).to_return do
        account.update!(user: new_user)
        { body: File.binread(file_from_fixtures("cropped.png")) }
      end

      described_class.import_url_for_user(url, user, associated_account_id: account.id)

      expect(user.reload.uploaded_avatar_id).to eq(provider_upload.id)
      expect(user.user_avatar.selected_user_associated_account_id).to eq(nil)
      expect(new_user.reload.uploaded_avatar_id).to eq(nil)
      expect(account.reload.avatar_upload_id).to eq(provider_upload.id)
    end

    it "creates user_avatar record if missing" do
      user = Fabricate(:user)
      user.user_avatar.destroy
      user.reload

      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))

      UserAvatar.import_url_for_user("logo.png", user)
      user.reload

      expect(user.uploaded_avatar_id).not_to eq(nil)
      expect(user.user_avatar.custom_upload_id).to eq(user.uploaded_avatar_id)
    end

    it "can leave gravatar alone" do
      upload = Fabricate(:upload)

      user = Fabricate(:user, uploaded_avatar_id: upload.id)
      user.user_avatar.update_columns(gravatar_upload_id: upload.id)

      stub_request(:get, "http://thisfakesomething.something.com/").to_return(
        status: 200,
        body: file_from_fixtures("logo.png"),
        headers: {
        },
      )

      url = "http://thisfakesomething.something.com/"

      expect do UserAvatar.import_url_for_user(url, user, override_gravatar: false) end.to change {
        Upload.count
      }.by(1)

      user.reload
      expect(user.uploaded_avatar_id).to eq(upload.id)

      last_id = Upload.last.id

      expect(last_id).not_to eq(upload.id)
      expect(user.user_avatar.custom_upload_id).to eq(last_id)
    end

    describe "when avatar url returns an invalid status code" do
      it "leaves the uploaded avatar unchanged" do
        stub_request(:get, "http://thisfakesomething.something.com/").to_return(
          status: 500,
          body: "",
          headers: {
          },
        )

        url = "http://thisfakesomething.something.com/"

        expect do UserAvatar.import_url_for_user(url, user) end.to_not change { Upload.count }

        user.reload

        expect(user.uploaded_avatar_id).to eq(nil)
        expect(user.user_avatar.custom_upload_id).to eq(nil)
      end
    end

    it "doesn't error out if the remote request fails" do
      FileHelper.stubs(:download).raises(FinalDestination::SSRFDetector::LookupFailedError.new)

      expect { UserAvatar.import_url_for_user(anything, user) }.not_to raise_error
    end
  end

  describe "ensure_consistency!" do
    it "cleans up incorrectly sized avatars" do
      SiteSetting.avatar_sizes = "10|20|30"

      upload = Fabricate(:upload)
      user_avatar = Fabricate(:user).user_avatar
      user_avatar.update_columns(custom_upload_id: upload.id)

      Fabricate(:optimized_image, upload: upload, width: 10, height: 10)
      Fabricate(:optimized_image, upload: upload, width: 15, height: 15)
      Fabricate(:optimized_image, upload: upload, width: 20, height: 20)

      UserAvatar.ensure_consistency!

      expect(OptimizedImage.where(upload_id: upload.id).pluck(:width, :height).sort).to eq(
        [[10, 10], [20, 20]],
      )

      # will not clean up if referenced
      Fabricate(:optimized_image, upload: upload, width: 15, height: 15)
      UploadReference.create!(upload: upload, target: Fabricate(:post))

      UserAvatar.ensure_consistency!

      expect(OptimizedImage.where(upload_id: upload.id).pluck(:width, :height).sort).to eq(
        [[10, 10], [15, 15], [20, 20]],
      )
    end

    it "removes dangling avatars" do
      upload1 = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      user_avatar = Fabricate(:user).user_avatar
      user_avatar.update_columns(gravatar_upload_id: upload1.id, custom_upload_id: upload2.id)

      upload1.destroy!
      upload2.destroy!

      user_avatar.reload
      expect(user_avatar.gravatar_upload_id).to eq(nil)
      expect(user_avatar.custom_upload_id).to eq(nil)

      user_avatar.update_columns(gravatar_upload_id: upload1.id, custom_upload_id: upload2.id)

      UserAvatar.ensure_consistency!

      user_avatar.reload
      expect(user_avatar.gravatar_upload_id).to eq(nil)
      expect(user_avatar.custom_upload_id).to eq(nil)
    end

    it "deletes avatars without users and does not remove avatars with users" do
      user_avatar_with_user = Fabricate(:user_avatar)
      user_avatar_without_user = Fabricate(:user_avatar)
      user_avatar_without_user.user.delete

      UserAvatar.ensure_consistency!

      expect(UserAvatar.exists?(user_avatar_with_user.id)).to eq true
      expect(UserAvatar.exists?(user_avatar_without_user.id)).to eq false
    end
  end
end
