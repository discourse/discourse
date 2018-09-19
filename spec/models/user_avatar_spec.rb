require 'rails_helper'

describe UserAvatar do
  let(:user) { Fabricate(:user) }
  let(:avatar) { user.create_user_avatar! }

  describe '#update_gravatar!' do
    let(:temp) { Tempfile.new('test') }
    let(:upload) { Fabricate(:upload, user: user) }

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
      expect do
        avatar.update_gravatar!
      end.to change { Upload.count }.by(1)

      upload = Upload.last

      expect(avatar.gravatar_upload).to eq(upload)
      expect(user.reload.uploaded_avatar).to eq(nil)
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

        expect(Upload.find_by(id: upload.id)).to eq(nil)

        new_upload = Upload.last

        expect(user.reload.uploaded_avatar).to eq(new_upload)
        expect(avatar.reload.gravatar_upload).to eq(new_upload)
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

      url = "http://thisfakesomething.something.com/"

      stub_request(:get, url)
        .to_return(status: 200, body: file_from_fixtures("logo.png"), headers: {})

      expect do
        UserAvatar.import_url_for_user(url, user, override_gravatar: false)
      end.to change { Upload.count }.by(1)

      user.reload
      expect(user.uploaded_avatar_id).to eq(1)
      expect(user.user_avatar.custom_upload_id).to eq(Upload.last.id)

      # now it gets super tricky cause we are going to use the same avatar for a diff user
      # we have to let this through cause SSO may be setting it, or social auth
      # plus end user may have changed mind, upload url1 / url2 / url1

      user2 = Fabricate(:user, uploaded_avatar_id: 1)
      user2.user_avatar.update_columns(gravatar_upload_id: 1)

      expect do
        UserAvatar.import_url_for_user(url, user2, override_gravatar: false)
      end.to change { Upload.count }.by(0)

      user2.reload
      expect(user2.uploaded_avatar_id).to eq(1)
      expect(user2.user_avatar.custom_upload_id).to eq(Upload.last.id)
    end

    it 'can correctly change custom avatar' do

      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)
      user.user_avatar.update_columns(custom_upload_id: upload.id)

      url = "http://somewhere.over.rainbow.com/unicorn.png"

      stub_request(:get, url)
        .to_return(status: 200, body: file_from_fixtures("logo.png"), headers: {})

      expect do
        UserAvatar.import_url_for_user(url, user, override_gravatar: false)
      end.to change { Upload.count }.by(1)

      user.reload
      upload_id = Upload.last.id
      expect(user.user_avatar.custom_upload_id).to eq(upload_id)
      expect(user.uploaded_avatar_id).to eq(upload_id)

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
