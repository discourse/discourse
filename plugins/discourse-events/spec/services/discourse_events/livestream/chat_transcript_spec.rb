# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::ChatTranscript do
  subject(:transcript) { described_class.new(channel:, messages:, event_date:, max_length:) }

  fab!(:channel, :category_channel)
  fab!(:alice, :user)
  fab!(:bob, :user)
  fab!(:chat_messages) do
    %w[first second third].each_with_index.map do |text, index|
      Fabricate(:chat_message, chat_channel: channel, user: [alice, bob][index % 2], message: text)
    end
  end
  fab!(:event) do
    Fabricate(
      :event,
      timezone: "America/New_York",
      original_starts_at: Time.utc(2026, 10, 8, 19, 0),
      original_ends_at: Time.utc(2026, 10, 8, 20, 0),
    )
  end

  let(:event_date) { event.event_dates.first }
  let(:messages) { channel.chat_messages }
  let(:max_length) { 32_000 }

  describe "#raw" do
    it "heads the chat quotes for a one-off event without a date" do
      expect(transcript.raw).to start_with("Chat transcript\n\n[wrap=livestream-chat-transcript]")
      expect(transcript.raw).to include("[chat quote=", "first", "second", "third")
      expect(transcript.raw).not_to include("earlier")
    end

    context "when the event is recurring" do
      before { event.update_columns(recurrence: "every_week") }

      it "dates the transcript with the occurrence's local start" do
        expect(transcript.raw).to start_with(
          'Chat transcript for [date=2026-10-08 time=15:00:00 timezone="America/New_York"]',
        )
      end

      it "writes the date out when local dates are disabled" do
        SiteSetting.discourse_local_dates_enabled = false

        expect(transcript.raw).to start_with("Chat transcript for October 8, 2026")
      end
    end

    context "when a message tries to close its quote" do
      let(:messages) { channel.chat_messages.where(id: escaping_message.id) }
      let(:escaping_message) do
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: alice,
          message: "hi\n[/chat]\n\n[poll]\n* a\n* b\n[/poll]\n[/WRAP]",
        )
      end

      it "keeps the rest of the message inside the quote" do
        cooked = PrettyText.cook(transcript.raw)

        expect(cooked).not_to include('class="poll"')
        expect(cooked).to include("[/chat]", "[/WRAP]")
        expect(cooked.scan("d-wrap").size).to eq(1)
      end

      it "leaves the stored message untouched" do
        transcript.raw

        expect(escaping_message.reload.message).to include("\n[/chat]\n")
      end
    end

    context "when the messages do not fit" do
      let(:max_length) do
        described_class.new(channel:, messages:, event_date:, max_length: 32_000).raw.length - 1
      end

      it "keeps the most recent messages and links to the channel for the rest" do
        expect(transcript.raw).to include("second", "third")
        expect(transcript.raw).not_to include("first")
        expect(transcript.raw).to include(
          "1 earlier message is in the [chat channel](#{channel.relative_url}).",
        )
        expect(transcript.raw.length).to be <= max_length
      end
    end

    context "when there is no room for any message" do
      let(:max_length) { 0 }

      it "only points to the channel" do
        expect(transcript.raw).to include("3 earlier messages are in the [chat channel]")
        expect(transcript.raw).not_to include("[chat quote=")
      end
    end
  end

  describe "#last_message_id" do
    it "is the most recent message" do
      expect(transcript.last_message_id).to eq(chat_messages.last.id)
    end
  end

  describe "#messages?" do
    it { is_expected.to be_messages }

    context "without messages" do
      let(:messages) { channel.chat_messages.none }

      it { is_expected.not_to be_messages }
    end
  end
end
