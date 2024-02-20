# frozen_string_literal: true

RSpec.describe Chat::StopMessageStreaming do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    let(:params) { { guardian: guardian } }
    let(:guardian) { Guardian.new(current_user) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }

    before { SiteSetting.chat_allowed_groups = [Group::AUTO_GROUPS[:everyone]] }

    context "with valid params" do
      fab!(:current_user) { Fabricate(:admin) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, streaming: true) }

      let(:params) { { guardian: guardian, channel_id: channel_1.id, message_id: message_1.id } }

      it { is_expected.to be_a_success }

      it "updates the streaming attribute to false" do
        expect { result }.to change { message_1.reload.streaming }.to eq(false)
      end

      it "publishes an event" do
        messages = MessageBus.track_publish { result }

        expect(messages.find { |m| m.channel == "/chat/#{channel_1.id}" }.data).to include(
          { "type" => "edit" },
        )
      end
    end

    context "when the channel_id is not provided" do
      it { is_expected.to fail_a_contract }
    end

    context "when the message_id is not provided" do
      let(:params) { { guardian: guardian, channel_id: channel_1.id } }

      it { is_expected.to fail_a_contract }
    end

    context "when the message doesnt exist" do
      let(:params) { { guardian: guardian, channel_id: channel_1.id, message_id: -999 } }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when the message is a reply" do
      let(:params) { { guardian: guardian, channel_id: channel_1.id, message_id: reply.id } }

      context "when the OM is from current user" do
        fab!(:original_message) do
          Fabricate(:chat_message, chat_channel: channel_1, user: current_user)
        end
        fab!(:reply) do
          Fabricate(:chat_message, chat_channel: channel_1, in_reply_to: original_message)
        end

        it { is_expected.to be_a_success }
      end

      context "when the OM is not from current user" do
        fab!(:original_message) do
          Fabricate(:chat_message, chat_channel: channel_1, user: Fabricate(:user))
        end
        fab!(:reply) do
          Fabricate(:chat_message, chat_channel: channel_1, in_reply_to: original_message)
        end

        context "when current user is a regular user" do
          it { is_expected.to fail_a_policy(:can_stop_streaming) }
        end

        context "when current user is an admin" do
          fab!(:current_user) { Fabricate(:admin) }

          it { is_expected.to be_a_success }
        end
      end
    end

    context "when the message is not a reply" do
      let(:params) { { guardian: guardian, channel_id: channel_1.id, message_id: message.id } }

      fab!(:message) { Fabricate(:chat_message, chat_channel: channel_1) }

      context "when current user is a regular user" do
        it { is_expected.to fail_a_policy(:can_stop_streaming) }
      end

      context "when current user is an admin" do
        fab!(:current_user) { Fabricate(:admin) }

        it { is_expected.to be_a_success }
      end
    end
  end
end
