# frozen_string_literal: true

require "system_message"
require "topic_subtype"

RSpec.describe SystemMessage do
  describe "#create" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    before { SiteSetting.site_contact_username = admin.username }

    it "should create a post correctly" do
      system_message = SystemMessage.new(user)
      post = system_message.create(:welcome_invite)
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.subtype).to eq(TopicSubtype.system_message)

      expect(topic.allowed_users.pluck(:user_id)).to contain_exactly(user.id, admin.id)

      expect(UserArchivedMessage.where(user_id: admin.id, topic_id: topic.id).count).to eq(1)
    end

    it "can create a post from system user in user selected locale" do
      SiteSetting.allow_user_locale = true
      user_de = Fabricate(:user, locale: "de")
      system_user = Discourse.system_user

      post = SystemMessage.create_from_system_user(user_de, :welcome_invite)
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.title).to eq(
        I18n.with_locale(:de) do
          I18n.t("system_messages.welcome_invite.subject_template", site_name: SiteSetting.title)
        end,
      )
      expect(topic.subtype).to eq(TopicSubtype.system_message)

      expect(topic.allowed_users.pluck(:user_id)).to contain_exactly(user_de.id, system_user.id)

      expect(UserArchivedMessage.where(user_id: system_user.id, topic_id: topic.id).count).to eq(0)
    end

    it "allows message_title and message_raw ops to override content" do
      user = Fabricate(:user)
      system_user = Discourse.system_user

      post =
        SystemMessage.create_from_system_user(
          user,
          :welcome_invite,
          { message_title: "override title", message_raw: "override body" },
        )
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.title).to eq("override title")
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(post.raw).to eq("override body")
    end

    it "should allow site_contact_group_name" do
      group = Fabricate(:group)
      SiteSetting.site_contact_group_name = group.name

      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly(group)

      group.update!(name: "anewname")
      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to eq([])
    end

    it "sends event with post object" do
      system_message = SystemMessage.new(user)

      event =
        DiscourseEvent.track(:system_message_sent) { system_message.create(:tl2_promotion_message) }

      expect(event[:event_name]).to eq(:system_message_sent)
      expect(event[:params].first[:post]).to eq(Post.last)
      expect(event[:params].first[:message_type]).to eq(:tl2_promotion_message)
    end

    it "sends an event before the system message is sent" do
      system_message = SystemMessage.new(user)

      event =
        DiscourseEvent.track(:before_system_message_sent) do
          system_message.create(:tl2_promotion_message)
        end

      expect(event[:event_name]).to eq(:before_system_message_sent)
      expect(event[:params].first[:message_type]).to eq(:tl2_promotion_message)
      expect(event[:params].first[:recipient]).to eq(user)
    end
  end
end
