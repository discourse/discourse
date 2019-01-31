require 'rails_helper'

describe UserAvatar do
  let(:user) { Fabricate(:user) }
  let(:avatar) { user.create_user_avatar! }

  describe '#update_gravatar!' do
    let(:temp) { Tempfile.new('test') }
    let(:upload) { Fabricate(:upload, user: user) }

    describe "when working" do

      before do
        temp.binmode
        # tiny valid png
        temp.write(Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw=="))
        temp.rewind
        FileHelper.expects(:download).returns(temp)
      end

      after do
        temp.unlink
      end

      it 'can update gravatars' do
        freeze_time Time.now

        expect { avatar.update_gravatar! }.to change { Upload.count }.by(1)

        expect(avatar.gravatar_upload).to eq(Upload.last)
        expect(avatar.last_gravatar_download_attempt).to eq(Time.now)
        expect(user.reload.uploaded_avatar).to eq(nil)

        expect do
          avatar.destroy
        end.to_not change { Upload.count }

      end

      describe 'when user has an existing custom upload' do
        it "should not change the user's uploaded avatar" do
          user.update!(uploaded_avatar: upload)

          avatar.update!(
            custom_upload: upload,
            gravatar_upload: Fabricate(:upload, user: user)
          )

          avatar.update_gravatar!

          expect(upload.reload).to eq(upload)
          expect(user.reload.uploaded_avatar).to eq(upload)
          expect(avatar.reload.custom_upload).to eq(upload)
          expect(avatar.gravatar_upload).to eq(Upload.last)
        end
      end

      describe 'when user has an existing gravatar' do
        it "should update the user's uploaded avatar correctly" do
          user.update!(uploaded_avatar: upload)
          avatar.update!(gravatar_upload: upload)

          avatar.update_gravatar!

          # old upload to be cleaned up via clean_up_uploads
          expect(Upload.find_by(id: upload.id)).not_to eq(nil)

          new_upload = Upload.last

          expect(user.reload.uploaded_avatar).to eq(new_upload)
          expect(avatar.reload.gravatar_upload).to eq(new_upload)
        end
      end
    end

    describe "when failing" do

      it "always update 'last_gravatar_download_attempt'" do
        freeze_time Time.now

        FileHelper.expects(:download).raises(SocketError)

        expect do
          expect { avatar.update_gravatar! }.to raise_error(SocketError)
        end.to_not change { Upload.count }

        expect(avatar.last_gravatar_download_attempt).to eq(Time.now)
      end

    end

    describe "404 should be silent, nothing to do really" do

      it "does nothing when avatar is 404" do

        freeze_time Time.now

        stub_request(:get, "https://www.gravatar.com/avatar/#{avatar.user.email_hash}.png?d=404&s=360").
          to_return(status: 404, body: "", headers: {})

        expect do
          avatar.update_gravatar!
        end.to_not change { Upload.count }

        expect(avatar.last_gravatar_download_attempt).to eq(Time.now)
      end
    end

  end

  context '.import_url_for_user' do

    it 'creates user_avatar record if missing' do
      user = Fabricate(:user)
      user.user_avatar.destroy
      user.reload

      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))

      UserAvatar.import_url_for_user("logo.png", user)
      user.reload

      expect(user.uploaded_avatar_id).not_to eq(nil)
      expect(user.user_avatar.custom_upload_id).to eq(user.uploaded_avatar_id)
    end

    it 'can leave gravatar alone' do
      user = Fabricate(:user, uploaded_avatar_id: 1)
      user.user_avatar.update_columns(gravatar_upload_id: 1)

      stub_request(:get, "http://thisfakesomething.something.com/")
        .to_return(status: 200, body: file_from_fixtures("logo.png"), headers: {})

      url = "http://thisfakesomething.something.com/"

      expect do
        UserAvatar.import_url_for_user(url, user, override_gravatar: false)
      end.to change { Upload.count }.by(1)

      user.reload
      expect(user.uploaded_avatar_id).to eq(1)
      expect(user.user_avatar.custom_upload_id).to eq(Upload.last.id)
    end

    describe 'when avatar url returns an invalid status code' do
      it 'should not do anything' do
        stub_request(:get, "http://thisfakesomething.something.com/")
          .to_return(status: 500, body: "", headers: {})

        url = "http://thisfakesomething.something.com/"

        expect do
          UserAvatar.import_url_for_user(url, user)
        end.to_not change { Upload.count }

        user.reload

        expect(user.uploaded_avatar_id).to eq(nil)
        expect(user.user_avatar.custom_upload_id).to eq(nil)
      end
    end
  end

  describe "ensure_consistency!" do

    it "will clean up dangling avatars" do
      upload1 = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      user_avatar = Fabricate(:user).user_avatar

      user_avatar.update_columns(
        gravatar_upload_id: upload1.id,
        custom_upload_id: upload2.id
      )

      upload1.destroy!
      upload2.destroy!

      user_avatar.reload
      expect(user_avatar.gravatar_upload_id).to eq(nil)
      expect(user_avatar.custom_upload_id).to eq(nil)

      user_avatar.update_columns(
        gravatar_upload_id: upload1.id,
        custom_upload_id: upload2.id
      )

      UserAvatar.ensure_consistency!

      user_avatar.reload
      expect(user_avatar.gravatar_upload_id).to eq(nil)
      expect(user_avatar.custom_upload_id).to eq(nil)
    end

  end
end
