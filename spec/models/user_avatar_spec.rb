require 'rails_helper'

describe UserAvatar do
  let(:user) { Fabricate(:user) }
  let(:avatar) { user.create_user_avatar! }

  it 'can update gravatars' do
    temp = Tempfile.new('test')
    temp.binmode
    # tiny valid png
    temp.write(Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw=="))
    temp.rewind
    FileHelper.expects(:download).returns(temp)
    avatar.update_gravatar!
    temp.unlink
    expect(avatar.gravatar_upload).not_to eq(nil)
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
