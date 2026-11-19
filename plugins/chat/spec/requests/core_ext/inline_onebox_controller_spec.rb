# frozen_string_literal: true

RSpec.describe InlineOneboxController do
  fab!(:current_user, :user)
  fab!(:direct_message_user_1, :user)
  fab!(:direct_message_user_2, :user)
  fab!(:public_channel, :category_channel)
  fab!(:private_channel) do
    Fabricate(
      :direct_message_channel,
      users: [direct_message_user_1, direct_message_user_2],
      threading_enabled: true,
    )
  end
  fab!(:private_thread) do
    Fabricate(:chat_thread, channel: private_channel, title: "Private thread title")
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_public_channels = true
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
    sign_in(current_user)
  end

  it "does not disclose a private thread title through a public channel URL" do
    get "/chat/api/channels/#{private_channel.id}/threads/#{private_thread.id}"

    expect(response.status).to eq(403)

    chat_thread_url = "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/t/#{private_thread.id}"
    InlineOneboxer.invalidate(chat_thread_url)

    get "/inline-onebox.json", params: { urls: [chat_thread_url] }

    expect(response.status).to eq(200)
    expect(response.body).not_to include(private_thread.title)
    expect(response.parsed_body["inline-oneboxes"]).to eq([])
  end

  describe "a thread whose original message was trashed" do
    fab!(:thread_channel) { Fabricate(:category_channel, threading_enabled: true) }
    fab!(:original_message) do
      Fabricate(:chat_message, chat_channel: thread_channel, message: "thread original secret")
    end
    fab!(:thread) do
      Fabricate(
        :chat_thread,
        channel: thread_channel,
        original_message: original_message,
        title: "thread title secret",
      )
    end
    let(:chat_thread_url) { "#{Discourse.base_url}#{thread.relative_url}" }

    it "does not disclose the thread title" do
      InlineOneboxer.invalidate(chat_thread_url)

      get "/inline-onebox.json", params: { urls: [chat_thread_url] }

      expect(response.status).to eq(200)
      expect(response.body).to include("thread title secret")

      original_message.trash!
      InlineOneboxer.invalidate(chat_thread_url)

      get "/inline-onebox.json", params: { urls: [chat_thread_url] }

      expect(response.status).to eq(200)
      expect(response.body).not_to include("thread title secret")
    end

    it "does not disclose a reply through its message link" do
      reply = Fabricate(:chat_message, chat_channel: thread_channel, thread: thread)
      chat_message_url = "#{Discourse.base_url}#{reply.url}"
      InlineOneboxer.invalidate(chat_message_url)

      get "/inline-onebox.json", params: { urls: [chat_message_url] }

      expect(response.parsed_body["inline-oneboxes"].map { |onebox| onebox["url"] }).to eq(
        [chat_message_url],
      )

      original_message.trash!
      InlineOneboxer.invalidate(chat_message_url)

      get "/inline-onebox.json", params: { urls: [chat_message_url] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["inline-oneboxes"]).to eq([])
    end
  end
end
