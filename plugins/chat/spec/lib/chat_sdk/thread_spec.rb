# frozen_string_literal: true

require "rails_helper"

describe ChatSDK::Thread do
  describe ".update_title" do
    fab!(:thread_1) { Fabricate(:chat_thread) }

    let(:params) do
      {
        title: "New Title",
        channel_id: thread_1.channel_id,
        thread_id: thread_1.id,
        guardian: Discourse.system_user.guardian,
      }
    end

    it "changes the title" do
      expect { described_class.update_title(**params) }.to change { thread_1.reload.title }.from(
        thread_1.title,
      ).to(params[:title])
    end

    context "when missing param" do
      it "fails" do
        params.delete(:thread_id)

        expect { described_class.update_title(**params) }.to raise_error("Thread can't be blank")
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

    context "when the threadind is not enabled" do
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

    context "when target_message doesn’t exist" do
      it "fails" do
        expect { described_class.messages(**params, target_message_id: -999) }.to raise_error(
          "Target message doesn't exist",
        )
      end
    end
  end
end
