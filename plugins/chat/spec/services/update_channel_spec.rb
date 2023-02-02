# frozen_string_literal: true

RSpec.describe Chat::Service::UpdateChannel do
  subject(:result) do
    described_class.call(guardian: guardian, channel_id: channel.id, status: "open")
  end

  fab!(:channel) { Fabricate(:chat_channel) }

  let(:guardian) { Guardian.new(current_user) }

  context "when the user cannot edit the channel" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, name: "cool channel")
    end

    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:invalid_access) }
  end

  context "when the user tries to edit a DM channel" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: dm_channel.id, name: "cool channel")
    end

    fab!(:current_user) { Fabricate(:admin) }
    let!(:dm_channel) do
      Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
    end

    it do
      is_expected.to fail_a_contract.with_error(
        I18n.t("chat.errors.cant_update_direct_message_channel"),
      )
    end
  end

  context "when the name, slug, and description are provided by a valid user" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        channel_id: channel.id,
        name: "cool channel",
        description: "a channel description",
        slug: "snail",
      )
    end

    fab!(:current_user) { Fabricate(:admin) }

    let(:message) do
      MessageBus.track_publish(ChatPublisher::CHANNEL_EDITS_MESSAGE_BUS_CHANNEL) { result }.first
    end

    it "works" do
      expect(result).to be_a_success
      expect(result.channel).to have_attributes(
        name: "cool channel",
        slug: "snail",
        description: "a channel description",
      )
    end

    it "publishes a MessageBus message" do
      expect(message.data).to eq(
        {
          chat_channel_id: channel.id,
          name: "cool channel",
          description: "a channel description",
          slug: "snail",
        },
      )
    end
  end

  context "when the name is blank" do
    subject(:result) { described_class.call(guardian: guardian, channel_id: channel.id, name: " ") }

    fab!(:current_user) { Fabricate(:admin) }

    it "nils out the name" do
      expect(result).to be_a_success
      expect(result.channel.name).to be_nil
    end
  end

  context "when the description is blank" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, description: " ")
    end

    fab!(:current_user) { Fabricate(:admin) }

    it "nils out the description" do
      expect(result).to be_a_success
      expect(result.channel.description).to be_nil
    end
  end

  context "when the auto_join_users and allow_channel_wide_mentions settings are provided by a valid user" do
    subject(:result) do
      described_class.call(
        guardian: guardian,
        channel_id: channel.id,
        auto_join_users: true,
        allow_channel_wide_mentions: true,
      )
    end

    fab!(:current_user) { Fabricate(:admin) }

    before { channel.update!(auto_join_users: false, allow_channel_wide_mentions: false) }

    it "works" do
      expect(result).to be_a_success
      expect(channel.reload).to have_attributes(
        auto_join_users: true,
        allow_channel_wide_mentions: true,
      )
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
