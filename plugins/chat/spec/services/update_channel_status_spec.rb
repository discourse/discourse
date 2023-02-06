# frozen_string_literal: true

RSpec.describe(Chat::Service::UpdateChannelStatus) do
  subject(:result) do
    described_class.call(guardian: guardian, channel_id: channel.id, status: status)
  end

  fab!(:channel) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:admin) }

  let(:guardian) { Guardian.new(current_user) }
  let(:status) { "open" }

  context "when no channel_id is given" do
    subject(:result) { described_class.call(guardian: guardian, status: status) }

    it { is_expected.to fail_to_find_a_model(:channel) }
  end

  context "when user is not allowed to change channel status" do
    fab!(:current_user) { Fabricate(:user) }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when status is not allowed" do
    (ChatChannel.statuses.keys - ChatChannel.editable_statuses.keys).each do |na_status|
      context "when status is '#{na_status}'" do
        let(:status) { na_status }

        it { is_expected.to be_a_failure }
      end
    end
  end

  context "when new status is the same than the existing one" do
    let(:status) { channel.status }

    it { is_expected.to fail_a_policy(:check_channel_permission) }
  end

  context "when status is allowed" do
    let(:status) { "closed" }

    it { is_expected.to be_a_success }

    it "changes the status" do
      result
      expect(channel.reload).to be_closed
    end
  end
end
