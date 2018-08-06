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

      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
      UserAvatar.import_url_for_user("logo.png", user, override_gravatar: false)

      user.reload
      expect(user.uploaded_avatar_id).to eq(1)
      expect(user.user_avatar.custom_upload_id).to eq(Upload.last.id)
    end

    describe 'when avatar url returns an invalid status code' do
      it 'should not do anything' do
        stub_request(:get, "http://thisfakesomething.something.com/")
          .to_return(status: 500, body: "", headers: {})

        url = "http://thisfakesomething.something.com/"

        UserAvatar.import_url_for_user(url, user)

        user.reload

        expect(user.uploaded_avatar_id).to eq(nil)
        expect(user.user_avatar.custom_upload_id).to eq(nil)
      end
    end
  end
end
