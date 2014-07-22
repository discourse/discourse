require 'spec_helper'
require 'system_message'
require 'topic_subtype'

describe SystemMessage do

  let!(:admin) { Fabricate(:admin) }

  context 'send' do

    let(:user) { Fabricate(:user) }
    let(:system_message) { SystemMessage.new(user) }
    let(:post) { system_message.create(:welcome_invite) }
    let(:topic) { post.topic }

    it 'should create a post correctly' do
      SiteSetting.stubs(:max_post_length).returns(100_000)
      post.should be_present
      post.should be_valid
      topic.should be_private_message
      topic.should be_valid
      topic.subtype.should == TopicSubtype.system_message
      topic.allowed_users.include?(user).should be_true
    end
  end


end
