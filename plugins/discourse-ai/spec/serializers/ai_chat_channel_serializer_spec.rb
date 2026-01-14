# frozen_string_literal: true

RSpec.describe AiChatChannelSerializer do
  fab!(:admin)

  before { enable_current_plugin }

  describe "#title" do
    context "when the channel is a DM" do
      fab!(:dm_channel, :direct_message_channel)

      it "display every participant" do
        serialized = described_class.new(dm_channel, scope: Guardian.new(admin), root: nil)

        expect(serialized.title).to eq(dm_channel.title(nil))
      end
    end

    context "when the channel is a regular one" do
      fab!(:channel, :chat_channel)

      it "displays the category title" do
        serialized = described_class.new(channel, scope: Guardian.new(admin), root: nil)

        expect(serialized.title).to eq(channel.title)
      end
    end
  end
end
