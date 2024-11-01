# frozen_string_literal: true

RSpec.describe Chat::StopMessageStreaming do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_id: message_1.id } }
    let(:dependencies) { { guardian: guardian } }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, streaming: true) }

    before do
      channel_1.add(current_user)
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    context "with valid params" do
      fab!(:current_user) { Fabricate(:admin) }

      it { is_expected.to run_successfully }

      it "updates the streaming attribute to false" do
        expect { result }.to change { message_1.reload.streaming }.to eq(false)
      end

      it "publishes an event" do
        messages = MessageBus.track_publish { result }

        expect(messages.find { |m| m.channel == "/chat/#{channel_1.id}" }.data).to include(
          { "type" => "edit" },
        )
      end

      it "leaves the presence channel" do
        message_2 =
          Fabricate(:chat_message, chat_channel: channel_1, streaming: true, use_service: true)
        params[:message_id] = message_2.id
        presence_channel = PresenceChannel.new(message_2.presence_channel_name)

        expect { result }.to change { presence_channel.count }.by(-1)
      end
    end

    context "when the user is not part of the channel" do
      before { channel_1.membership_for(current_user).destroy! }

      it { is_expected.to fail_to_find_a_model(:membership) }

      context "when the user is a bot" do
        fab!(:current_user) { Discourse.system_user }

        it { is_expected.to run_successfully }
      end
    end

    context "when the message_id is not provided" do
      before { params[:message_id] = nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the message doesnt exist" do
      before { params[:message_id] = -999 }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when the message is a reply" do
      context "when the OM is from current user" do
        fab!(:original_message) do
          Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
        end
        fab!(:reply) do
          Fabricate(:chat_message, chat_channel: channel_1, in_reply_to: original_message)
        end

        before { params[:message_id] = reply.id }

        it { is_expected.to run_successfully }
      end

      context "when the OM is not from current user" do
        fab!(:original_message) do
          Fabricate(:chat_message, chat_channel: channel_1, user: Fabricate(:user))
        end
        fab!(:reply) do
          Fabricate(:chat_message, chat_channel: channel_1, in_reply_to: original_message)
        end

        before { params[:message_id] = reply.id }

        context "when current user is a regular user" do
          it { is_expected.to fail_a_policy(:can_stop_streaming) }
        end

        context "when current user is a bot" do
          fab!(:current_user) { Discourse.system_user }

          it { is_expected.to run_successfully }
        end

        context "when current user is an admin" do
          fab!(:current_user) { Fabricate(:admin) }

          it { is_expected.to run_successfully }
        end
      end
    end

    context "when the message is not a reply" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel_1) }

      before { params[:message_id] = message.id }

      context "when current user is a regular user" do
        it { is_expected.to fail_a_policy(:can_stop_streaming) }
      end

      context "when current user is a bot" do
        fab!(:current_user) { Discourse.system_user }

        it { is_expected.to run_successfully }
      end

      context "when current user is an admin" do
        fab!(:current_user) { Fabricate(:admin) }

        it { is_expected.to run_successfully }
      end
    end
  end
end
