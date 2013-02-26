require 'spec_helper'
require 'system_message'

describe SystemMessage do

  let!(:admin) { Fabricate(:admin) }

  context 'send' do

    let(:user) { Fabricate(:user) }
    let(:system_message) { SystemMessage.new(user) }
    let(:post) { system_message.create(:welcome_invite) }
    let(:topic) { post.topic }

    it 'should create a post' do
      post.should be_present
    end

    it 'should be a private message' do
      topic.should be_private_message
    end

    it 'should be visible by the user' do
      topic.allowed_users.include?(user).should be_true
    end

  end

  context '#system_user' do

    it 'returns the user specified by the site setting system_username' do
      SiteSetting.stubs(:system_username).returns(admin.username)
      SystemMessage.system_user.should == admin
    end

    it 'returns the first admin user otherwise' do
      SiteSetting.stubs(:system_username).returns(nil)
      SystemMessage.system_user.should == admin
    end

  end

end
