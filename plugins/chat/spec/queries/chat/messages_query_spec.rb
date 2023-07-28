# frozen_string_literal: true

RSpec.describe Chat::MessagesQuery do
  subject(:query) do
    described_class.call(guardian: current_user.guardian, channel: channel, **options)
  end

  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:current_user) { Fabricate(:user) }

  let(:include_thread_messages) { false }
  let(:thread_id) { nil }
  let(:page_size) { nil }
  let(:direction) { nil }
  let(:target_message_id) { nil }
  let(:target_date) { nil }
  let(:options) do
    {
      thread_id: thread_id,
      include_thread_messages: include_thread_messages,
      page_size: page_size,
      direction: direction,
      target_message_id: target_message_id,
      target_date: target_date,
    }
  end

  fab!(:message_1) do
    message = Fabricate(:chat_message, chat_channel: channel)
    message.update!(created_at: 2.days.ago)
    message
  end
  fab!(:message_2) do
    message = Fabricate(:chat_message, chat_channel: channel)
    message.update!(created_at: 6.hours.ago)
    message
  end
  fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel) }

  context "when target_message_id provided" do
    let(:target_message) { message_2 }
    let(:target_message_id) { target_message.id }

    it "queries messages in the channel and finds the past and future messages" do
      expect(query).to eq(
        past_messages: [message_1],
        future_messages: [message_3],
        target_message: target_message,
        can_load_more_past: false,
        can_load_more_future: false,
      )
    end

    it "does not include deleted messages" do
      message_3.trash!
      expect(query[:future_messages]).to eq([])
    end

    it "still includes the target message if it is deleted" do
      target_message.trash!
      expect(query[:target_message]).to eq(target_message)
    end

    it "can_load_more_past is true when the past messages reach the limit" do
      stub_const(described_class, "PAST_MESSAGE_LIMIT", 1) do
        expect(query[:can_load_more_past]).to be_truthy
      end
    end

    it "can_load_more_future is true when the future messages reach the limit" do
      stub_const(described_class, "FUTURE_MESSAGE_LIMIT", 1) do
        expect(query[:can_load_more_future]).to be_truthy
      end
    end

    it "limits results of paginated query when page_size is not set" do
      options[:target_message_id] = nil
      stub_const(described_class, "MAX_PAGE_SIZE", 1) { expect(query[:messages].length).to eq(1) }
    end

    describe "when some messages are in threads" do
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

      it "does not include messages which are thread replies but does include thread original messages" do
        message_3.update!(thread: thread)
        expect(query[:future_messages]).to eq([thread.original_message])
      end

      context "when include_thread_messages is true" do
        let(:include_thread_messages) { true }

        it "does include messages which are part of a thread" do
          message_3.update!(
            thread: thread,
            created_at: thread.original_message.created_at + 1.minute,
          )
          expect(query[:future_messages]).to eq([thread.original_message, message_3])
        end
      end

      context "when thread_id is provided" do
        let(:thread_id) { thread.id }
        it "does include messages which are part of a thread" do
          message_3.update!(
            thread: thread,
            created_at: thread.original_message.created_at + 1.minute,
          )
          expect(query[:future_messages]).to eq([thread.original_message, message_3])
        end
      end
    end

    context "when the user can moderate chat" do
      before { current_user.update!(admin: true) }

      it "does include deleted messages" do
        message_3.trash!
        expect(query[:future_messages]).to eq([message_3])
      end
    end
  end

  context "when target_date provided" do
    let(:target_date) { 1.day.ago }

    it "queries messages in the channel and finds the past and future messages" do
      expect(query).to eq(
        past_messages: [message_1],
        future_messages: [message_2, message_3],
        target_date: target_date,
        can_load_more_past: false,
        can_load_more_future: false,
        target_message_id: message_2.id,
      )
    end
  end

  context "when target_message_id not provided" do
    it "queries messages in the channel" do
      expect(query).to eq(
        messages: [message_1, message_2, message_3],
        can_load_more_past: false,
        can_load_more_future: false,
      )
    end

    context "when the messages length is equal to the page_size" do
      let(:page_size) { 3 }

      it "can_load_more_past is true" do
        expect(query[:can_load_more_past]).to be_truthy
      end
    end

    context "when direction is future" do
      let(:direction) { described_class::FUTURE }

      it "returns messages in ascending order by created_at" do
        expect(query[:messages]).to eq([message_1, message_2, message_3])
      end

      context "when the messages length is equal to the page_size" do
        let(:page_size) { 3 }

        it "can_load_more_future is true" do
          expect(query[:can_load_more_future]).to be_truthy
        end
      end
    end

    context "when direction is past" do
      let(:direction) { described_class::PAST }

      it "returns messages in ascending order by created_at" do
        expect(query[:messages]).to eq([message_1, message_2, message_3])
      end

      context "when the messages length is equal to the page_size" do
        let(:page_size) { 3 }

        it "can_load_more_past is true" do
          expect(query[:can_load_more_past]).to be_truthy
        end
      end
    end
  end
end
