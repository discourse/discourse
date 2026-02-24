# frozen_string_literal: true

RSpec.describe Chat::RebakeMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
    it { is_expected.to validate_presence_of(:chat_channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:message, :chat_message)

    let(:guardian) { Guardian.new(admin) }
    let(:params) { { message_id: message.id, chat_channel_id: message.chat_channel_id } }
    let(:dependencies) { { guardian: } }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    end

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the channel does not exist" do
      let(:params) { { message_id: message.id, chat_channel_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when the user cannot access the channel" do
      fab!(:private_channel) do
        Fabricate(
          :private_category_channel,
          group: Fabricate(:group),
          chatable: Fabricate(:private_category, group: Fabricate(:group)),
        )
      end

      let(:current_user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(current_user) }
      let(:params) { { message_id: -999, chat_channel_id: private_channel.id } }

      it { is_expected.to fail_a_policy(:can_access_channel) }
    end

    context "when the message does not exist" do
      let(:params) { { message_id: -1, chat_channel_id: message.chat_channel_id } }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when the message does not belong to the channel" do
      let(:other_channel) { Fabricate(:category_channel) }
      let(:params) { { message_id: message.id, chat_channel_id: other_channel.id } }

      it { is_expected.to fail_to_find_a_model(:message) }
    end

    context "when the user does not have permission to rebake" do
      let(:current_user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(current_user) }

      it { is_expected.to fail_a_policy(:can_rebake) }
    end

    context "when the user has permission to rebake" do
      it { is_expected.to run_successfully }

      it "enqueues a process message job" do
        expect_enqueued_with(
          job: Jobs::Chat::ProcessMessage,
          args: {
            chat_message_id: message.id,
          },
        ) { result }
      end
    end
  end
end
