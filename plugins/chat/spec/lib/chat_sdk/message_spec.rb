# frozen_string_literal: true

describe ChatSDK::Message do
  describe ".create" do
    fab!(:channel_1) { Fabricate(:chat_channel) }

    let(:guardian) { Discourse.system_user.guardian }
    let(:params) do
      {
        blocks: nil,
        enforce_membership: false,
        raw: "something",
        channel_id: channel_1.id,
        guardian: guardian,
      }
    end

    it "creates the message" do
      message = described_class.create(**params)

      expect(message.message).to eq("something")
    end

    context "when providing blocks" do
      before do
        params[:blocks] = [
          {
            type: "actions",
            elements: [{ type: "button", value: "foo", text: { type: "plain_text", text: "Foo" } }],
          },
        ]
      end

      context "when user is a bot" do
        it "saves the blocks" do
          message = described_class.create(**params)

          expect(message.blocks[0]).to include(
            "type" => "actions",
            "schema_version" => 1,
            "block_id" => an_instance_of(String),
            "elements" => [
              {
                "schema_version" => 1,
                "type" => "button",
                "value" => "foo",
                "action_id" => an_instance_of(String),
                "text" => {
                  "type" => "plain_text",
                  "text" => "Foo",
                },
              },
            ],
          )
        end
      end

      context "when user is not a bot" do
        fab!(:user)

        let(:guardian) { user.guardian }

        before { channel_1.add(user) }

        it "fails" do
          expect { described_class.create(**params) }.to raise_error(
            "Only bots can create messages with blocks",
          )
        end
      end
    end

    it "sets created_by_sdk to true" do
      message = described_class.create(**params)
      expect(message).to have_attributes(created_by_sdk: true)
    end

    context "when thread_id is present" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

      it "creates the message in a thread" do
        message = described_class.create(**params, thread_id: thread_1.id)

        expect(message.thread_id).to eq(thread_1.id)
      end
    end

    context "when force_thread is present" do
      it "creates the message in a thread" do
        message_1 = described_class.create(**params)
        message_2 =
          described_class.create(**params, in_reply_to_id: message_1.id, force_thread: true)

        expect(message_2.thread.force).to eq(true)
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
          "Couldn't find membership for user with id: `#{params[:guardian].user.id}`",
        )
      end
    end

    context "when membership is enforced" do
      it "works" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
        params[:enforce_membership] = true
        params[:guardian] = Fabricate(:user).guardian

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
              .track_publish("/chat/#{channel_1.id}") { helper.stream(raw: " test") }
              .find { |m| m.data["type"] == "edit" }

          expect(edit.data["chat_message"]["message"]).to eq("something test")
        end

      expect(created_message.streaming).to eq(false)
      expect(created_message.message).to eq("something test")
    end
  end

  describe ".stop_stream" do
    fab!(:message_1) { Fabricate(:chat_message, message: "first") }

    before do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      message_1.chat_channel.add(message_1.user)
      message_1.update!(streaming: true)
    end

    it "stop streaming message" do
      described_class.stop_stream(message_id: message_1.id, guardian: message_1.user.guardian)

      expect(message_1.reload.streaming).to eq(false)
    end

    context "when user can't stop streaming" do
      it "fails" do
        user = Fabricate(:user)
        message_1.chat_channel.add(user)

        expect {
          described_class.stop_stream(message_id: message_1.id, guardian: user.guardian)
        }.to raise_error("User with id: `#{user.id}` can't stop streaming this message")
      end
    end

    context "when user is not part of the channel" do
      fab!(:message_1) do
        Fabricate(:chat_message, chat_channel: Fabricate(:private_category_channel))
      end

      it "fails" do
        user = Fabricate(:user)

        expect {
          described_class.stop_stream(message_id: message_1.id, guardian: user.guardian)
        }.to raise_error("Couldn't find membership for user with id: `#{user.id}`")
      end
    end
  end

  describe ".start_stream" do
    fab!(:message_1) { Fabricate(:chat_message, message: "first") }

    it "enables streaming" do
      edit =
        MessageBus
          .track_publish("/chat/#{message_1.chat_channel.id}") do
            described_class.start_stream(
              message_id: message_1.id,
              guardian: message_1.user.guardian,
            )
          end
          .find { |m| m.data["type"] == "edit" }

      expect(edit.data["chat_message"]["message"]).to eq("first")
      expect(message_1.reload.streaming).to eq(true)
    end
  end

  describe ".stream" do
    fab!(:message_1) { Fabricate(:chat_message, message: "first\n") }

    before do
      message_1.chat_channel.add(message_1.user)
      message_1.update!(streaming: true)
    end

    it "streams" do
      edit =
        MessageBus
          .track_publish("/chat/#{message_1.chat_channel.id}") do
            described_class.stream(
              raw: " test\n",
              message_id: message_1.id,
              guardian: message_1.user.guardian,
            )
          end
          .find { |m| m.data["type"] == "edit" }

      expect(edit.data["chat_message"]["message"]).to eq("first\n test\n")
      expect(message_1.reload.streaming).to eq(true)
    end
  end
end
