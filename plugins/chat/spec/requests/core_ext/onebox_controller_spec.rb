# frozen_string_literal: true

RSpec.describe OneboxController do
  fab!(:current_user, :user)
  fab!(:direct_message_user_1, :user)
  fab!(:direct_message_user_2, :user)
  fab!(:direct_message_user_3, :user)
  fab!(:public_channel, :category_channel)
  fab!(:private_channel) do
    Fabricate(
      :direct_message_channel,
      users: [direct_message_user_1, direct_message_user_2, direct_message_user_3],
      threading_enabled: true,
    )
  end
  fab!(:private_original_message) do
    Fabricate(
      :chat_message,
      chat_channel: private_channel,
      user: direct_message_user_1,
      message: "private thread secret message",
    )
  end
  fab!(:private_thread) do
    Fabricate(:chat_thread, channel: private_channel, original_message: private_original_message)
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    sign_in(current_user)
  end

  it "does not render a private thread when the URL uses a public channel id" do
    get "/chat/api/channels/#{private_channel.id}/threads/#{private_thread.id}"

    expect(response.status).to eq(403)
    expect(response.parsed_body["errors"]).to be_present

    get "/onebox.json",
        params: {
          url: "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/t/#{private_thread.id}",
          refresh: "true",
        }

    expect(response.status).to eq(200)
    expect(response.body).to include(public_channel.name)
    expect(response.body).not_to include(private_original_message.message)
  end

  it "does not onebox a public channel message for a user excluded from chat" do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
    restricted_message =
      Fabricate(
        :chat_message,
        chat_channel: public_channel,
        message: "restricted chat message content",
      )

    get "/chat/api/channels"

    expect(response.status).to eq(403)
    expect(response.parsed_body["errors"]).to be_present

    get "/onebox.json",
        params: {
          url: "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/#{restricted_message.id}",
          refresh: "true",
        }

    expect(response.status).to eq(200)
    expect(response.body).not_to include(restricted_message.message)
  end

  describe "a thread whose original message was trashed" do
    fab!(:thread_channel) { Fabricate(:category_channel, threading_enabled: true) }
    fab!(:original_message) do
      Fabricate(
        :chat_message,
        chat_channel: thread_channel,
        user: direct_message_user_1,
        message: "thread original secret",
      )
    end
    fab!(:thread) do
      Fabricate(
        :chat_thread,
        channel: thread_channel,
        original_message: original_message,
        title: "thread title secret",
      )
    end
    fab!(:reply) do
      Fabricate(
        :chat_message,
        chat_channel: thread_channel,
        user: direct_message_user_1,
        thread: thread,
        message: "thread reply secret",
      )
    end

    before { thread.update!(replies_count: 1) }

    it "does not onebox the reply" do
      get "/onebox.json", params: { url: "#{Discourse.base_url}#{reply.url}", refresh: "true" }

      expect(response.status).to eq(200)
      expect(response.body).to include("thread reply secret")

      original_message.trash!

      get "/onebox.json", params: { url: "#{Discourse.base_url}#{reply.url}", refresh: "true" }

      expect(response.status).to eq(200)
      expect(response.body).not_to include("thread reply secret")
    end

    it "does not onebox the thread card" do
      get "/onebox.json",
          params: {
            url: "#{Discourse.base_url}#{thread.relative_url}",
            refresh: "true",
          }

      expect(response.status).to eq(200)
      expect(response.body).to include("thread title secret")

      original_message.trash!

      get "/onebox.json",
          params: {
            url: "#{Discourse.base_url}#{thread.relative_url}",
            refresh: "true",
          }

      expect(response.status).to eq(200)
      expect(response.body).not_to include("thread title secret")
    end
  end

  describe "a reply in a channel with threading disabled" do
    fab!(:inline_channel, :category_channel)
    fab!(:original_message) do
      Fabricate(
        :chat_message,
        chat_channel: inline_channel,
        user: direct_message_user_1,
        message: "inline original secret",
      )
    end
    fab!(:thread) do
      Fabricate(:chat_thread, channel: inline_channel, original_message: original_message)
    end
    fab!(:reply) do
      Fabricate(
        :chat_message,
        chat_channel: inline_channel,
        user: direct_message_user_1,
        thread: thread,
        message: "inline reply secret",
      )
    end

    it "still oneboxes the reply after the original message is trashed" do
      original_message.trash!

      get "/onebox.json", params: { url: "#{Discourse.base_url}#{reply.url}", refresh: "true" }

      expect(response.status).to eq(200)
      expect(response.body).to include("inline reply secret")
    end
  end

  describe "a reply in a forced thread of a channel with threading disabled" do
    fab!(:inline_channel, :category_channel)
    fab!(:original_message) do
      Fabricate(
        :chat_message,
        chat_channel: inline_channel,
        user: direct_message_user_1,
        message: "forced original secret",
      )
    end
    fab!(:thread) do
      Fabricate(
        :chat_thread,
        channel: inline_channel,
        original_message: original_message,
        force: true,
      )
    end
    fab!(:reply) do
      Fabricate(
        :chat_message,
        chat_channel: inline_channel,
        user: direct_message_user_1,
        thread: thread,
        message: "forced reply secret",
      )
    end

    it "does not onebox the reply after the original message is trashed" do
      original_message.trash!

      get "/onebox.json", params: { url: "#{Discourse.base_url}#{reply.url}", refresh: "true" }

      expect(response.status).to eq(200)
      expect(response.body).not_to include("forced reply secret")
    end
  end
end
