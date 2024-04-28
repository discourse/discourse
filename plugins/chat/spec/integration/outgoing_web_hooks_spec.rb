# frozen_string_literal: true

RSpec.describe "Outgoing chat webhooks" do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "chat messages" do
    fab!(:web_hook) { Fabricate(:outgoing_chat_message_web_hook) }
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    let(:message_content) { "This is a test message" }
    let(:new_message_content) { "This is the edited message" }
    let(:job_args) do
      Jobs::EmitWebHookEvent
        .jobs
        .map { |job| job["args"].first }
        .find { |args| args["event_type"] == "chat_message" }
    end
    let(:event_name) { job_args["event_name"] }
    let(:event_category_id) { job_args["category_id"] }
    let(:payload) { JSON.parse(job_args["payload"]) }

    def expect_response_to_be_successful
      expect(response.status).to eq(200)
    end

    def expect_web_hook_event_name_to_be(name)
      expect(event_name).to eq(name)
    end

    def expect_web_hook_event_category_to_be(category)
      expect(event_category_id).to eq(category.id)
    end

    def expect_web_hook_payload_message_to_match(message:, user:, &block)
      payload_message = payload["message"]

      expect(payload_message["id"]).to eq(message.id)
      expect(payload_message["message"]).to eq(message.message)
      expect(payload_message["cooked"]).to eq(message.cooked)
      expect(payload_message["created_at"]).to eq(message.created_at.iso8601)
      expect(payload_message["excerpt"]).to eq(message.excerpt)
      expect(payload_message["chat_channel_id"]).to eq(message.chat_channel_id)
      expect(payload_message["mentioned_users"]).to be_empty
      expect(payload_message["available_flags"]).to be_empty
      expect(payload_message["user"]["id"]).to eq(user.id)
      expect(payload_message["user"]["username"]).to eq(user.username)
      expect(payload_message["user"]["avatar_template"]).to eq(user.avatar_template)
      expect(payload_message["user"]["admin"]).to eq(user.admin?)
      expect(payload_message["user"]["staff"]).to eq(user.staff?)
      expect(payload_message["user"]["moderator"]).to eq(user.moderator?)
      expect(payload_message["user"]["new_user"]).to eq(user.trust_level == TrustLevel[0])
      expect(payload_message["user"]["primary_group_name"]).to eq(user.primary_group&.name)
      expect(payload_message["uploads"]).to be_empty

      yield(payload_message) if block_given?
    end

    def expect_web_hook_payload_channel_to_match_category(channel:, category:, &block)
      payload_channel = payload["channel"]

      expect(payload_channel["id"]).to eq(channel.id)
      expect(payload_channel["allow_channel_wide_mentions"]).to eq(
        channel.allow_channel_wide_mentions,
      )
      expect(payload_channel["chatable_id"]).to eq(category.id)
      expect(payload_channel["chatable_type"]).to eq("Category")
      expect(payload_channel["chatable_url"]).to eq(category.url)
      expect(payload_channel["title"]).to eq(channel.title)
      expect(payload_channel["slug"]).to eq(channel.slug)

      yield(payload_channel) if block_given?
    end

    def expect_web_hook_payload_channel_to_match_direct_message(channel:, direct_message:, &block)
      payload_channel = payload["channel"]

      expect(payload_channel["id"]).to eq(channel.id)
      expect(payload_channel["allow_channel_wide_mentions"]).to eq(
        channel.allow_channel_wide_mentions,
      )
      expect(payload_channel["chatable_id"]).to eq(direct_message.id)
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
      expect(payload_channel["title"]).to eq(channel.title(user1))
      expect(payload_channel["slug"]).to be_nil

      yield(payload_channel) if block_given?
    end

    context "for a category channel" do
      fab!(:category)
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }
      fab!(:chat_message) do
        Fabricate(:chat_message, use_service: true, chat_channel: chat_channel, user: user1)
      end

      before { sign_in(user1) }

      it "triggers a webhook when a chat message is created" do
        post "/chat/#{chat_channel.id}.json", params: { message: message_content }

        expect_response_to_be_successful
        expect_web_hook_event_name_to_be("chat_message_created")
        expect_web_hook_event_category_to_be(category)
        expect_web_hook_payload_message_to_match(
          message: Chat::Message.last,
          user: user1,
        ) { |payload_message| expect(payload_message["message"]).to eq(message_content) }
        expect_web_hook_payload_channel_to_match_category(channel: chat_channel, category: category)
      end

      it "triggers a webhook when a chat message is edited" do
        put "/chat/api/channels/#{chat_channel.id}/messages/#{chat_message.id}.json",
            params: {
              message: new_message_content,
            }

        expect_response_to_be_successful
        expect_web_hook_event_name_to_be("chat_message_edited")
        expect_web_hook_event_category_to_be(category)
        expect_web_hook_payload_message_to_match(
          message: Chat::Message.last,
          user: user1,
        ) { |payload_message| expect(payload_message["message"]).to eq(new_message_content) }
        expect_web_hook_payload_channel_to_match_category(channel: chat_channel, category: category)
      end

      it "triggers a webhook when a chat message is trashed" do
        delete "/chat/api/channels/#{chat_message.chat_channel_id}/messages/#{chat_message.id}.json"

        expect_response_to_be_successful
        expect(chat_message.reload.trashed?).to eq(true)
        expect_web_hook_event_name_to_be("chat_message_trashed")
        expect_web_hook_event_category_to_be(category)
        expect_web_hook_payload_message_to_match(message: chat_message, user: user1)
        expect_web_hook_payload_channel_to_match_category(channel: chat_channel, category: category)
      end

      it "triggers a webhook when a trashed chat message is restored" do
        chat_message.trash!(user1)
        expect(chat_message.reload.trashed?).to eq(true)

        put "/chat/api/channels/#{chat_channel.id}/messages/#{chat_message.id}/restore.json"

        expect_response_to_be_successful
        expect(chat_message.reload.trashed?).to eq(false)
        expect_web_hook_event_name_to_be("chat_message_restored")
        expect_web_hook_event_category_to_be(category)
        expect_web_hook_payload_message_to_match(message: chat_message, user: user1)
        expect_web_hook_payload_channel_to_match_category(channel: chat_channel, category: category)
      end
    end

    context "for a direct message channel" do
      fab!(:direct_message) { Fabricate(:direct_message, users: [user1, user2]) }
      fab!(:direct_message_channel) { Fabricate(:direct_message_channel, chatable: direct_message) }
      fab!(:chat_message) do
        Fabricate(
          :chat_message,
          use_service: true,
          chat_channel: direct_message_channel,
          user: user1,
        )
      end

      before { sign_in(user1) }

      it "triggers a webhook when a chat message is created" do
        post "/chat/#{direct_message_channel.id}.json", params: { message: message_content }

        expect_response_to_be_successful
        expect_web_hook_event_name_to_be("chat_message_created")
        expect_web_hook_payload_message_to_match(
          message: Chat::Message.last,
          user: user1,
        ) { |payload_message| expect(payload_message["message"]).to eq(message_content) }
        expect_web_hook_payload_channel_to_match_direct_message(
          channel: direct_message_channel,
          direct_message: direct_message,
        )
      end

      it "triggers a webhook when a chat message is edited" do
        put "/chat/api/channels/#{direct_message_channel.id}/messages/#{chat_message.id}.json",
            params: {
              message: new_message_content,
            }

        expect_response_to_be_successful
        expect_web_hook_event_name_to_be("chat_message_edited")
        expect_web_hook_payload_message_to_match(
          message: Chat::Message.last,
          user: user1,
        ) { |payload_message| expect(payload_message["message"]).to eq(new_message_content) }
        expect_web_hook_payload_channel_to_match_direct_message(
          channel: direct_message_channel,
          direct_message: direct_message,
        )
      end

      it "triggers a webhook when a chat message is trashed" do
        delete "/chat/api/channels/#{chat_message.chat_channel_id}/messages/#{chat_message.id}.json"

        expect_response_to_be_successful
        expect(chat_message.reload.trashed?).to eq(true)
        expect_web_hook_event_name_to_be("chat_message_trashed")
        expect_web_hook_payload_message_to_match(message: chat_message, user: user1)
        expect_web_hook_payload_channel_to_match_direct_message(
          channel: direct_message_channel,
          direct_message: direct_message,
        )
      end

      it "triggers a webhook when a trashed chat message is restored" do
        chat_message.trash!(user1)
        expect(chat_message.reload.trashed?).to eq(true)

        put "/chat/api/channels/#{direct_message_channel.id}/messages/#{chat_message.id}/restore.json"

        expect_response_to_be_successful
        expect(chat_message.reload.trashed?).to eq(false)
        expect_web_hook_event_name_to_be("chat_message_restored")
        expect_web_hook_payload_message_to_match(message: chat_message, user: user1)
        expect_web_hook_payload_channel_to_match_direct_message(
          channel: direct_message_channel,
          direct_message: direct_message,
        )
      end
    end
  end
end
