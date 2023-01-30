# frozen_string_literal: true

RSpec.describe Chat::Service::UpdateChannel do
  fab!(:channel) { Fabricate(:chat_channel) }
  let(:guardian) { Guardian.new(current_user) }
  subject(:result) { described_class.call(guardian: guardian, channel: channel, status: "open") }

  context "when the user cannot edit the channel" do
    fab!(:current_user) { Fabricate(:user) }

    subject(:result) do
      described_class.call(guardian: guardian, channel: channel, name: "cool channel")
    end

    it "fails" do
      expect(result).to fail_guardian_check(:can_edit_chat_channel?)
    end
  end

  context "when the user tries to edit a DM channel" do
    fab!(:current_user) { Fabricate(:admin) }
    let!(:dm_channel) do
      Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
    end

    subject(:result) do
      described_class.call(guardian: guardian, channel: dm_channel, name: "cool channel")
    end

    it "fails" do
      expect(result).to fail_contract_with_error(
        I18n.t("chat.errors.cant_update_direct_message_channel"),
      )
    end
  end

  context "when the name and description are provided by a valid user" do
    fab!(:current_user) { Fabricate(:admin) }

    subject(:result) do
      described_class.call(
        guardian: guardian,
        channel: channel,
        name: "cool channel",
        description: "a channel description",
      )
    end

    it "works" do
      expect(result).to be_a_success
      expect(result.channel.name).to eq("cool channel")
      expect(result.channel.description).to eq("a channel description")
    end

    it "publishes a MessageBus message" do
      message =
        MessageBus.track_publish(ChatPublisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL) { result }.first
      expect(message.data).to eq(
        { chat_channel_id: channel.id, name: channel.name, description: channel.description },
      )
    end
  end

  context "when the auto_join_users and allow_channel_wide_mentions settings are provided by a valid user" do
    fab!(:current_user) { Fabricate(:admin) }

    before { channel.update!(auto_join_users: false, allow_channel_wide_mentions: false) }

    subject(:result) do
      described_class.call(
        guardian: guardian,
        channel: channel,
        auto_join_users: true,
        allow_channel_wide_mentions: true,
      )
    end

    it "works" do
      expect(result).to be_a_success
      expect(result.channel.auto_join_users).to eq(true)
      expect(result.channel.allow_channel_wide_mentions).to eq(true)
    end

    it "auto joins users" do
      expect_enqueued_with(
        job: :auto_manage_channel_memberships,
        args: {
          chat_channel_id: channel.id,
        },
      ) { result }
    end
  end
end
