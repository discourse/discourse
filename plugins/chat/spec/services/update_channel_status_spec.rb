# frozen_string_literal: true

RSpec.describe(Chat::Service::UpdateChannelStatus) do
  fab!(:channel) { Fabricate(:chat_channel) }

  let(:guardian) { Guardian.new(current_user) }

  context "when status is given as a string" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, status: "open")
    end

    fab!(:current_user) { Fabricate(:admin) }

    it "converts status to a symbol" do
      expect(result.status).to eq(:open)
    end
  end

  context "when no channel_id is given" do
    subject(:result) { described_class.call(guardian: guardian, status: :open) }

    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to fail_to_find_a_model(:channel) }
  end

  context "when user is not allowed to change channel status" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, status: :open)
    end

    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when status is not allowed" do
    fab!(:current_user) { Fabricate(:admin) }

    (ChatChannel.statuses.keys - ChatChannel.editable_statuses.keys).each do |status|
      context "when status is '#{status}'" do
        subject(:result) do
          described_class.call(guardian: guardian, channel_id: channel.id, status: status)
        end

        it { is_expected.to be_a_failure }
      end
    end
  end

  context "when new status is the same than the existing one" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, status: :open)
    end

    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when status is allowed" do
    subject(:result) do
      described_class.call(guardian: guardian, channel_id: channel.id, status: :closed)
    end

    fab!(:current_user) { Fabricate(:admin) }

    it { is_expected.to be_a_success }

    it "changes the status" do
      result
      expect(channel.reload).to be_closed
    end
  end
end
