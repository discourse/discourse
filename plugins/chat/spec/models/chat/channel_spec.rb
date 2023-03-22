# frozen_string_literal: true

RSpec.describe Chat::Channel do
  fab!(:category_channel1) { Fabricate(:category_channel) }
  fab!(:dm_channel1) { Fabricate(:direct_message_channel) }

  describe "#relative_url" do
    context "when the slug is nil" do
      it "uses a - instead" do
        category_channel1.slug = nil
        expect(category_channel1.relative_url).to eq("/chat/c/-/#{category_channel1.id}")
      end
    end

    context "when the slug is not nil" do
      before { category_channel1.update!(slug: "some-cool-channel") }

      it "includes the slug for the channel" do
        expect(category_channel1.relative_url).to eq(
          "/chat/c/some-cool-channel/#{category_channel1.id}",
        )
      end
    end
  end

  describe ".ensure_consistency!" do
    fab!(:category_channel2) { Fabricate(:category_channel) }
    fab!(:category_channel3) { Fabricate(:category_channel) }
    fab!(:category_channel4) { Fabricate(:category_channel) }
    fab!(:dm_channel2) { Fabricate(:direct_message_channel) }

    before do
      Fabricate(:chat_message, chat_channel: category_channel1)
      Fabricate(:chat_message, chat_channel: category_channel1)
      Fabricate(:chat_message, chat_channel: category_channel1)

      Fabricate(:chat_message, chat_channel: category_channel2)
      Fabricate(:chat_message, chat_channel: category_channel2)
      Fabricate(:chat_message, chat_channel: category_channel2)
      Fabricate(:chat_message, chat_channel: category_channel2)

      Fabricate(:chat_message, chat_channel: category_channel3)

      Fabricate(:chat_message, chat_channel: dm_channel2)
      Fabricate(:chat_message, chat_channel: dm_channel2)
    end

    describe "updating messages_count for all channels" do
      it "counts correctly" do
        described_class.ensure_consistency!
        expect(category_channel1.reload.messages_count).to eq(3)
        expect(category_channel2.reload.messages_count).to eq(4)
        expect(category_channel3.reload.messages_count).to eq(1)
        expect(category_channel4.reload.messages_count).to eq(0)
        expect(dm_channel1.reload.messages_count).to eq(0)
        expect(dm_channel2.reload.messages_count).to eq(2)
      end

      it "does not count deleted messages" do
        category_channel3.chat_messages.last.trash!
        described_class.ensure_consistency!
        expect(category_channel3.reload.messages_count).to eq(0)
      end

      it "does not update deleted channels" do
        described_class.ensure_consistency!
        category_channel3.chat_messages.last.trash!
        category_channel3.trash!
        described_class.ensure_consistency!
        expect(category_channel3.reload.messages_count).to eq(1)
      end
    end
  end

  describe "#allow_channel_wide_mentions" do
    it "defaults to true" do
      expect(category_channel1.allow_channel_wide_mentions).to be(true)
    end

    it "cant be nullified" do
      expect { category_channel1.update!(allow_channel_wide_mentions: nil) }.to raise_error(
        ActiveRecord::NotNullViolation,
      )
    end
  end
end
