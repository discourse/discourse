# frozen_string_literal: true

describe Chat::InlineOneboxHandler do
  fab!(:private_category_group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: private_category_group) }
  fab!(:private_channel) { Fabricate(:category_channel, chatable: private_category) }
  fab!(:public_channel) { Fabricate(:category_channel) }
  fab!(:user)
  fab!(:user_2) { Fabricate(:user, active: false) }
  fab!(:user_3) { Fabricate(:user, staged: true) }
  fab!(:user_4) { Fabricate(:user, suspended_till: 3.weeks.from_now) }

  let(:public_chat_url) { "#{Discourse.base_url}/chat/c/-/#{public_channel.id}" }
  let(:private_chat_url) { "#{Discourse.base_url}/chat/c/-/#{private_channel.id}" }
  let(:invalid_chat_url) { "#{Discourse.base_url}/chat/c/-/999" }

  context "when the link is to a public channel" do
    describe "channel" do
      it "renders an inline onebox for the channel" do
        expect(
          Chat::InlineOneboxHandler.handle(public_chat_url, { channel_id: public_channel.id }),
        ).to eq(
          {
            url: public_chat_url,
            title: I18n.t("chat.onebox.inline_to_channel", chat_channel: public_channel.name),
          },
        )
      end

      it "does not render an inline onebox for a channel which does not exist" do
        public_channel.trash!
        expect(
          Chat::InlineOneboxHandler.handle(public_chat_url, { channel_id: public_channel.id }),
        ).to be_nil
      end
    end

    describe "message" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: public_channel) }
      let(:public_chat_message_url) do
        "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/#{message.id}"
      end

      it "renders an inline onebox for a message" do
        expect(
          Chat::InlineOneboxHandler.handle(
            public_chat_message_url,
            { channel_id: public_channel.id, message_id: message.id },
          ),
        ).to eq(
          {
            url: public_chat_message_url,
            title:
              I18n.t(
                "chat.onebox.inline_to_message",
                chat_channel: public_channel.name,
                message_id: message.id,
                username: message.user.username,
              ),
          },
        )
      end

      it "does not render an inline onebox for a message which does not exist" do
        message.trash!
        expect(
          Chat::InlineOneboxHandler.handle(
            public_chat_message_url,
            { channel_id: public_channel.id, message_id: message.id },
          ),
        ).to be_nil
      end
    end

    describe "thread" do
      fab!(:thread) do
        Fabricate(:chat_thread, channel: public_channel, title: "Let's talk about some games")
      end
      let(:public_chat_thread_url) do
        "#{Discourse.base_url}/chat/c/-/#{public_channel.id}/t/#{thread.id}"
      end

      it "renders an inline onebox for a thread" do
        expect(
          Chat::InlineOneboxHandler.handle(
            public_chat_thread_url,
            { channel_id: public_channel.id, thread_id: thread.id },
          ),
        ).to eq(
          {
            url: public_chat_thread_url,
            title:
              I18n.t(
                "chat.onebox.inline_to_thread",
                chat_channel: public_channel.name,
                thread_id: thread.id,
                thread_title: thread.title,
              ),
          },
        )
      end

      it "renders an inline onebox for a thread with no title" do
        thread.update!(title: nil)
        expect(
          Chat::InlineOneboxHandler.handle(
            public_chat_thread_url,
            { channel_id: public_channel.id, thread_id: thread.id },
          ),
        ).to eq(
          {
            url: public_chat_thread_url,
            title:
              I18n.t(
                "chat.onebox.inline_to_thread_no_title",
                chat_channel: public_channel.name,
                thread_id: thread.id,
                thread_title: thread.title,
              ),
          },
        )
      end

      it "does not render an inline onebox for a thread which does not exist" do
        thread.destroy!
        expect(
          Chat::InlineOneboxHandler.handle(
            public_chat_thread_url,
            { channel_id: public_channel.id, thread_id: thread.id },
          ),
        ).to be_nil
      end
    end
  end

  context "when the link is to a private channel" do
    fab!(:message) { Fabricate(:chat_message, chat_channel: private_channel) }
    fab!(:thread) do
      Fabricate(:chat_thread, channel: private_channel, title: "Let's talk about some games")
    end
    let(:private_chat_thread_url) do
      "#{Discourse.base_url}/chat/c/-/#{private_channel.id}/t/#{thread.id}"
    end
    let(:private_chat_message_url) do
      "#{Discourse.base_url}/chat/c/-/#{private_channel.id}/#{message.id}"
    end

    it "does not render an inline onebox for the channel for any users" do
      expect(
        Chat::InlineOneboxHandler.handle(private_chat_url, { channel_id: private_channel.id }),
      ).to be_nil
    end

    it "does not render an inline onebox for the channel message for any users" do
      expect(
        Chat::InlineOneboxHandler.handle(
          private_chat_message_url,
          { channel_id: private_channel.id, message_id: message.id },
        ),
      ).to be_nil
    end

    it "does not render an inline onebox for the channel thread for any users" do
      expect(
        Chat::InlineOneboxHandler.handle(
          private_chat_thread_url,
          { channel_id: private_channel.id, thread_id: thread.id },
        ),
      ).to be_nil
    end
  end
end
