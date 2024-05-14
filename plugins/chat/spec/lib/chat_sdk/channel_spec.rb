# frozen_string_literal: true

describe ChatSDK::Channel do
  describe ".messages" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

    let(:params) { { channel_id: channel_1.id, guardian: Discourse.system_user.guardian } }

    it "loads the messages" do
      messages = described_class.messages(**params)

      expect(messages).to eq([message_1, message_2])
    end

    it "accepts page_size" do
      messages = described_class.messages(**params, page_size: 1)

      expect(messages).to eq([message_1])
    end

    context "when guardian can't see the channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }

      it "fails" do
        params[:guardian] = Fabricate(:user).guardian

        expect { described_class.messages(**params) }.to raise_error("Guardian can't view channel")
      end
    end

    context "when target_message doesn’t exist" do
      it "fails" do
        expect { described_class.messages(**params, target_message_id: -999) }.to raise_error(
          "Target message doesn't exist",
        )
      end
    end
  end
end
