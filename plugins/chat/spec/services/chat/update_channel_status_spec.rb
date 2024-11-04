# frozen_string_literal: true

RSpec.describe(Chat::UpdateChannelStatus) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it do
      is_expected.to validate_inclusion_of(:status).in_array(Chat::Channel.editable_statuses.keys)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:current_user) { Fabricate(:admin) }

    let(:params) { { channel_id:, status: } }
    let(:dependencies) { { guardian: } }
    let(:guardian) { Guardian.new(current_user) }
    let(:status) { "open" }
    let(:channel_id) { channel.id }

    context "when model is not found" do
      let(:channel_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when user is not allowed to change channel status" do
      let!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:check_channel_permission) }
    end

    context "when contract is invalid" do
      let(:status) { :invalid_status }

      it { is_expected.to fail_a_contract }
    end

    context "when new status is the same than the existing one" do
      let(:status) { channel.status }

      it { is_expected.to fail_a_policy(:check_channel_permission) }
    end

    context "when everything's ok" do
      let(:status) { "closed" }

      it { is_expected.to run_successfully }

      it "changes the status" do
        result
        expect(channel.reload).to be_closed
      end
    end
  end
end
