# frozen_string_literal: true

describe ChatSDK::Thread do
  describe ".update_title" do
    fab!(:thread_1) { Fabricate(:chat_thread) }

    let(:params) do
      { title: "New Title", thread_id: thread_1.id, guardian: Discourse.system_user.guardian }
    end

    it "changes the title" do
      expect { described_class.update_title(**params) }.to change { thread_1.reload.title }.from(
        thread_1.title,
      ).to(params[:title])
    end

    context "when missing param" do
      it "fails" do
        params.delete(:thread_id)

        expect { described_class.update_title(**params) }.to raise_error(
          "missing keyword: :thread_id",
        )
      end
    end

    context "when guardian can't see the channel" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: Fabricate(:private_category_channel)) }

      it "fails" do
        params[:guardian] = Fabricate(:user).guardian

        expect { described_class.update_title(**params) }.to raise_error(
          "Guardian can't view channel",
        )
      end
    end

    context "when guardian can't edit the thread" do
      it "fails" do
        params[:guardian] = Fabricate(:user).guardian

        expect { described_class.update_title(**params) }.to raise_error(
          "Guardian can't edit thread",
        )
      end
    end

    context "when the threading is not enabled" do
      before { thread_1.channel.update!(threading_enabled: false) }

      it "fails" do
        expect { described_class.update_title(**params) }.to raise_error(
          "Threading is not enabled for this channel",
        )
      end
    end

    context "when the thread doesn't exist" do
      it "fails" do
        params[:thread_id] = -999
        expect { described_class.update_title(**params) }.to raise_error(
          "Couldn’t find thread with id: `-999`",
        )
      end
    end
  end

  describe ".first_messages" do
    fab!(:thread_1) { Fabricate(:chat_thread) }
    fab!(:messages) do
      Fabricate.times(5, :chat_message, thread: thread_1, chat_channel: thread_1.channel)
    end

    let(:params) { { thread_id: thread_1.id, guardian: Discourse.system_user.guardian } }

    it "returns messages" do
      expect(described_class.first_messages(**params)).to eq([thread_1.original_message, *messages])
    end
  end

  describe ".last_messages" do
    fab!(:thread_1) { Fabricate(:chat_thread) }
    fab!(:messages) do
      Fabricate.times(
        5,
        :chat_message,
        thread: thread_1,
        chat_channel: thread_1.channel,
        use_service: true,
      )
    end

    let(:params) do
      { thread_id: thread_1.id, guardian: Discourse.system_user.guardian, page_size: 5 }
    end

    it "returns messages" do
      expect(described_class.last_messages(**params)).to eq([*messages])
    end
  end

  describe ".messages" do
    fab!(:thread_1) { Fabricate(:chat_thread) }
    fab!(:messages) do
      Fabricate.times(
        5,
        :chat_message,
        thread: thread_1,
        chat_channel: thread_1.channel,
        use_service: true,
      )
    end

    let(:params) { { thread_id: thread_1.id, guardian: Discourse.system_user.guardian } }

    it "returns messages" do
      expect(described_class.messages(**params)).to eq([thread_1.original_message, *messages])
    end

    describe "page_size:" do
      before { params[:page_size] = 2 }

      it "limits returned messages" do
        expect(described_class.messages(**params)).to eq([thread_1.original_message, messages[0]])
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
