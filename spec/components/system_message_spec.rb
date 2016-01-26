require 'rails_helper'
require 'system_message'
require 'topic_subtype'

describe SystemMessage do


  context 'send' do

    it 'should create a post correctly' do

      admin = Fabricate(:admin)
      user = Fabricate(:user)
      SiteSetting.site_contact_username = admin.username
      system_message = SystemMessage.new(user)
      post = system_message.create(:welcome_invite)
      topic = post.topic

      expect(post).to be_present
      expect(post).to be_valid
      expect(topic).to be_private_message
      expect(topic).to be_valid
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(topic.allowed_users.include?(user)).to eq(true)
      expect(topic.allowed_users.include?(admin)).to eq(true)

      expect(UserArchivedMessage.where(user_id: admin.id, topic_id: topic.id).length).to eq(1)
    end
  end


end
