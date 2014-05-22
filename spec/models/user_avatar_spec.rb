require 'spec_helper'

describe UserAvatar do
  let(:avatar){
    user = Fabricate(:user)
    user.create_user_avatar!
  }

  it 'can generate a system avatar' do
    avatar.update_system_avatar!
    avatar.system_upload.should_not be_nil
  end

  it 'can update gravatars' do
    temp = Tempfile.new('test')
    FileHelper.expects(:download).returns(temp)
    avatar.update_gravatar!
    temp.unlink
    avatar.gravatar_upload.should_not be_nil
  end
end
