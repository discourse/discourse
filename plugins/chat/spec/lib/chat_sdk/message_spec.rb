# frozen_string_literal: true

require "rails_helper"

describe ChatSDK::Message do
  describe ".create" do
    fab!(:channel_1) { Fabricate(:chat_channel) }

    let(:guardian) { Discourse.system_user.guardian }
    let(:params) do
      { enforce_membership: false, raw: "something", channel_id: channel_1.id, guardian: guardian }
    end

    it "creates the message" do
      message = described_class.create(**params)

      expect(message.message).to eq("something")
    end

    context "when thread_id is present" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

      it "creates the message in a thread" do
        message = described_class.create(**params, thread_id: thread_1.id)

        expect(message.thread_id).to eq(thread_1.id)
      end
    end

    context "when channel doesn’t exist" do
      it "fails" do
        expect { described_class.create(**params, channel_id: -999) }.to raise_error(
          "Couldn't find channel with id: `-999`",
        )
      end
    end

    context "when user can't join channel" do
      it "fails" do
        params[:guardian] = Fabricate(:user).guardian

        expect { described_class.create(**params) }.to raise_error(
          "User with id: `#{params[:guardian].user.id}` can't join this channel",
        )
      end
    end

    context "when membership is enforced" do
      it "works" do
        params[:enforce_membership] = true
        params[:guardian] = Fabricate(:user).guardian
        SiteSetting.chat_allowed_groups = [Group::AUTO_GROUPS[:everyone]]

        message = described_class.create(**params)

        expect(message.message).to eq("something")
      end
    end

    context "when thread doesn't exist" do
      it "fails" do
        expect { described_class.create(**params, thread_id: -999) }.to raise_error(
          "Couldn't find thread with id: `-999`",
        )
      end
    end

    context "when params are invalid" do
      it "fails" do
        expect { described_class.create(**params, raw: nil, channel_id: nil) }.to raise_error(
          "Chat channel can't be blank, Message can't be blank",
        )
      end
    end
  end

  describe ".create_with_stream" do
    fab!(:channel_1) { Fabricate(:chat_channel) }

    let(:guardian) { Discourse.system_user.guardian }
    let(:params) { { raw: "something", channel_id: channel_1.id, guardian: guardian } }

    it "allows streaming" do
      created_message =
        described_class.create_with_stream(**params) do |helper, message|
          expect(message.streaming).to eq(true)

          edit =
            MessageBus
              .track_publish("/chat/#{channel_1.id}") { helper.stream(raw: "test") }
              .find { |m| m.data["type"] == "edit" }

          expect(edit.data["chat_message"]["message"]).to eq("something test")
        end

      expect(created_message.streaming).to eq(false)
      expect(created_message.message).to eq("something test")
    end
  end
end
