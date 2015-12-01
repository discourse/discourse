require 'rails_helper'

describe UserAvatar do
  let(:avatar){
    user = Fabricate(:user)
    user.create_user_avatar!
  }

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
end
