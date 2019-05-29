# frozen_string_literal: true

require 'rails_helper'
require 'system_message'
require 'topic_subtype'

describe SystemMessage do

  context 'send' do

    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    before do
      SiteSetting.site_contact_username = admin.username
    end

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

      expect(UserArchivedMessage.where(user_id: admin.id, topic_id: topic.id).length).to eq(1)
    end

    it 'can create a post from system user in user selected locale' do
      SiteSetting.allow_user_locale = true
      user_de = Fabricate(:user, locale: 'de')
      system_user = Discourse.system_user

      post = SystemMessage.create_from_system_user(user_de, :welcome_invite)
      topic = post.topic

      expect(post.valid?).to eq(true)
      expect(topic).to be_private_message
      expect(topic).to be_valid
      expect(topic.title).to eq(I18n.with_locale(:de) { I18n.t("system_messages.welcome_invite.subject_template", site_name: SiteSetting.title) })
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(topic.allowed_users.include?(user_de)).to eq(true)
      expect(topic.allowed_users.include?(system_user)).to eq(true)
      expect(UserArchivedMessage.where(user_id: system_user.id, topic_id: topic.id).length).to eq(0)
    end

    it 'should allow site_contact_group_name' do
      group = Fabricate(:group)
      SiteSetting.site_contact_group_name = group.name

      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly(group)

      group.update!(name: "anewname")
      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly()
    end
  end

end
