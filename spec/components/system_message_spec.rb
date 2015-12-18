require 'rails_helper'
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
      expect(post).to be_present
      expect(post).to be_valid
      expect(topic).to be_private_message
      expect(topic).to be_valid
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(topic.allowed_users.include?(user)).to eq(true)
    end
  end


end
