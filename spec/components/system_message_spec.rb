require 'rails_helper'
require 'system_message'
require 'topic_subtype'

describe SystemMessage do
  context 'send' do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

    before { SiteSetting.site_contact_username = admin.username }

    it 'should create a post correctly' do
      system_message = SystemMessage.new(user)
      post = system_message.create(:welcome_invite)
      topic = post.topic

      expect(post.valid?).to eq(true)
      expect(topic).to be_private_message
      expect(topic).to be_valid
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(topic.allowed_users.include?(user)).to eq(true)
      expect(topic.allowed_users.include?(admin)).to eq(true)

      expect(
        UserArchivedMessage.where(user_id: admin.id, topic_id: topic.id).length
      ).to eq(1)
    end

    it 'should allow site_contact_group_name' do
      group = Fabricate(:group)
      SiteSetting.site_contact_group_name = group.name

      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly(group)

      group.update!(name: 'anewname')
      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly
    end
  end
end
