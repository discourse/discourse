# frozen_string_literal: true

RSpec.describe Chat::Action::SearchMessage::ApplyFiltersAndSorting do
  subject(:result) do
    described_class.call(messages: messages, exclude_threads: exclude_threads, sort: sort)
  end

  fab!(:current_user, :user)
  fab!(:channel, :chat_channel)

  let(:messages) { Chat::Message.where(chat_channel: channel) }
  let(:exclude_threads) { false }
  let(:sort) { "relevance" }

  before do
    channel.add(current_user)
    SiteSetting.chat_enabled = true
  end

  context "with thread exclusion" do
    fab!(:regular_message) do
      Fabricate(:chat_message, chat_channel: channel, message: "regular message")
    end
    fab!(:original_message) do
      Fabricate(:chat_message, chat_channel: channel, message: "original message")
    end
    fab!(:thread) { Fabricate(:chat_thread, channel: channel, original_message: original_message) }
    fab!(:thread_reply) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread, message: "thread reply")
    end

    context "when exclude_threads is true" do
      let(:exclude_threads) { true }

      it "excludes thread replies" do
        expect(result).not_to include(thread_reply)
      end

      it "includes original thread messages" do
        expect(result).to include(original_message)
      end

      it "includes regular messages" do
        expect(result).to include(regular_message)
      end
    end

    context "when exclude_threads is false" do
      let(:exclude_threads) { false }

      it "includes all messages" do
        expect(result).to contain_exactly(regular_message, original_message, thread_reply)
      end
    end
  end

  context "with sorting" do
    fab!(:message_1) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 3.days.ago, message: "oldest")
    end
    fab!(:message_2) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 2.days.ago, message: "middle")
    end
    fab!(:message_3) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 1.day.ago, message: "newest")
    end

    context "when sort is 'latest'" do
      let(:sort) { "latest" }

      it "orders messages by created_at descending" do
        expect(result.to_a).to eq([message_3, message_2, message_1])
      end
    end

    context "when sort is 'relevance'" do
      let(:sort) { "relevance" }

      it "returns all messages without specific ordering" do
        expect(result).to contain_exactly(message_1, message_2, message_3)
      end
    end

    context "when sort is nil" do
      let(:sort) { nil }

      it "returns all messages without specific ordering" do
        expect(result).to contain_exactly(message_1, message_2, message_3)
      end
    end
  end

  context "with both thread exclusion and sorting" do
    fab!(:regular_message) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 2.days.ago, message: "regular")
    end
    fab!(:original_message) do
      Fabricate(:chat_message, chat_channel: channel, created_at: 3.days.ago, message: "original")
    end
    fab!(:thread) { Fabricate(:chat_thread, channel: channel, original_message: original_message) }
    fab!(:thread_reply) do
      Fabricate(
        :chat_message,
        chat_channel: channel,
        thread: thread,
        created_at: 1.day.ago,
        message: "reply",
      )
    end

    let(:exclude_threads) { true }
    let(:sort) { "latest" }

    it "applies both filters and sorting" do
      expect(result.to_a).to eq([regular_message, original_message])
    end

    it "excludes thread replies" do
      expect(result).not_to include(thread_reply)
    end
  end

  context "with multiple threads" do
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_1_reply) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1, message: "reply 1")
    end
    fab!(:thread_2_reply) do
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2, message: "reply 2")
    end

    let(:exclude_threads) { true }

    it "includes both original messages" do
      expect(result).to include(thread_1.original_message, thread_2.original_message)
    end

    it "excludes all thread replies" do
      expect(result).not_to include(thread_1_reply, thread_2_reply)
    end
  end
end
