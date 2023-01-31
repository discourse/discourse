# frozen_string_literal: true

RSpec.describe(Chat::Service::UpdateChannelStatus) do
  let(:guardian) { Guardian.new(current_user) }

  context "when status is given as a string" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    subject(:result) { described_class.call(guardian: guardian, channel: channel, status: "open") }

    it "converts status to a symbol" do
      expect(result.status).to eq(:open)
    end
  end

  context "when no channel is given" do
    fab!(:current_user) { Fabricate(:admin) }

    subject(:result) { described_class.call(guardian: guardian, status: :open) }

    it "fails" do
      expect(result).to be_a_failure
    end
  end

  context "when user is not allowed to change channel status" do
    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel) }

    subject(:result) { described_class.call(guardian: guardian, channel: channel, status: :open) }

    it "fails" do
      expect(result[:"result.policy.invalid_access"]).to be_a_failure
    end
  end

  context "when status is not allowed" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    it "fails" do
      (ChatChannel.statuses.keys - ChatChannel.editable_statuses.keys).each do |status|
        result = described_class.call(guardian: guardian, channel: channel, status: status)
        expect(result).to be_a_failure
      end
    end
  end

  context "when new status is the same than the existing one" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    subject(:result) { described_class.call(guardian: guardian, channel: channel, status: :open) }

    it "changes the status" do
      expect(result).to be_a_failure
    end
  end

  context "when status is allowed" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:channel) { Fabricate(:chat_channel) }

    subject(:result) { described_class.call(guardian: guardian, channel: channel, status: :closed) }

    it "changes the status" do
      expect(result).to be_a_success
    end
  end
end
