# frozen_string_literal: true

RSpec.describe "chat webhooks" do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "chat messages" do
    fab!(:web_hook) { Fabricate(:chat_message_web_hook) }
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }

    let(:message) { "This is a message" }

    context "for a category channel" do
      fab!(:category) { Fabricate(:category) }
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }

      before do
        [user1, user2].each do |user|
          Chat::UserChatChannelMembership.create(
            user: user,
            chat_channel: chat_channel,
            following: true,
          )
        end
      end

      it "triggers a webhook when a chat message is created" do
        sign_in(user1)

        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)

        job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first
        expect(job_args["event_name"]).to eq("chat_message_created")
        payload = JSON.parse(job_args["payload"])

        payload["message"].tap do |payload_message|
          message = Chat::Message.last

          expect(payload_message["id"]).to eq(message.id)
          expect(payload_message["message"]).to eq(message.message)
          expect(payload_message["cooked"]).to eq(message.cooked)
          expect(payload_message["created_at"]).to eq(message.created_at.iso8601)
          expect(payload_message["excerpt"]).to eq(message.excerpt)
          expect(payload_message["chat_channel_id"]).to eq(message.chat_channel_id)
          expect(payload_message["mentioned_users"]).to be_empty
          expect(payload_message["available_flags"]).to be_empty
          expect(payload_message["user"]["id"]).to eq(user1.id)
          expect(payload_message["user"]["username"]).to eq(user1.username)
          expect(payload_message["user"]["avatar_template"]).to eq(user1.avatar_template)
          expect(payload_message["user"]["admin"]).to eq(user1.admin?)
          expect(payload_message["user"]["staff"]).to eq(user1.staff?)
          expect(payload_message["user"]["moderator"]).to eq(user1.moderator?)
          expect(payload_message["user"]["new_user"]).to eq(user1.trust_level == TrustLevel[0])
          expect(payload_message["user"]["primary_group_name"]).to eq(user1.primary_group&.name)
          expect(payload_message["uploads"]).to be_empty
        end

        payload["channel"].tap do |payload_channel|
          expect(payload_channel["id"]).to eq(chat_channel.id)
          expect(payload_channel["allow_channel_wide_mentions"]).to eq(
            chat_channel.allow_channel_wide_mentions,
          )
          expect(payload_channel["chatable_id"]).to eq(category.id)
          expect(payload_channel["chatable_type"]).to eq("Category")
          expect(payload_channel["chatable_url"]).to eq(category.url)
          expect(payload_channel["title"]).to eq(chat_channel.title)
          expect(payload_channel["slug"]).to eq(chat_channel.slug)
        end
      end
    end

    context "for a direct message channel" do
      fab!(:chatable) { Fabricate(:direct_message, users: [user1, user2]) }
      fab!(:direct_message_channel) { Fabricate(:direct_message_channel, chatable: chatable) }

      it "triggers a webhook when a chat message is created" do
        sign_in(user1)

        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)

        job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first
        expect(job_args["event_name"]).to eq("chat_message_created")
        payload = JSON.parse(job_args["payload"])

        payload["message"].tap do |payload_message|
          message = Chat::Message.last

          expect(payload_message["id"]).to eq(message.id)
          expect(payload_message["message"]).to eq(message.message)
          expect(payload_message["cooked"]).to eq(message.cooked)
          expect(payload_message["created_at"]).to eq(message.created_at.iso8601)
          expect(payload_message["excerpt"]).to eq(message.excerpt)
          expect(payload_message["chat_channel_id"]).to eq(message.chat_channel_id)
          expect(payload_message["mentioned_users"]).to be_empty
          expect(payload_message["available_flags"]).to be_empty
          expect(payload_message["user"]["id"]).to eq(user1.id)
          expect(payload_message["user"]["username"]).to eq(user1.username)
          expect(payload_message["user"]["avatar_template"]).to eq(user1.avatar_template)
          expect(payload_message["user"]["admin"]).to eq(user1.admin?)
          expect(payload_message["user"]["staff"]).to eq(user1.staff?)
          expect(payload_message["user"]["moderator"]).to eq(user1.moderator?)
          expect(payload_message["user"]["new_user"]).to eq(user1.trust_level == TrustLevel[0])
          expect(payload_message["user"]["primary_group_name"]).to eq(user1.primary_group&.name)
          expect(payload_message["uploads"]).to be_empty
        end

        payload["channel"].tap do |payload_channel|
          expect(payload_channel["id"]).to eq(direct_message_channel.id)
          expect(payload_channel["allow_channel_wide_mentions"]).to eq(
            direct_message_channel.allow_channel_wide_mentions,
          )
          expect(payload_channel["chatable_id"]).to eq(chatable.id)
          expect(payload_channel["chatable_type"]).to eq("DirectMessage")
          expect(payload_channel["chatable_url"]).to be_nil
          expect(payload_channel["chatable"]["users"][0]["id"]).to eq(user2.id)
          expect(payload_channel["chatable"]["users"][0]["username"]).to eq(user2.username)
          expect(payload_channel["chatable"]["users"][0]["name"]).to eq(user2.name)
          expect(payload_channel["chatable"]["users"][0]["avatar_template"]).to eq(
            user2.avatar_template,
          )
          expect(payload_channel["chatable"]["users"][0]["can_chat"]).to eq(true)
          expect(payload_channel["chatable"]["users"][0]["has_chat_enabled"]).to eq(true)
          expect(payload_channel["title"]).to eq(direct_message_channel.title(user1))
          expect(payload_channel["slug"]).to be_nil
        end
      end
    end
  end
end
