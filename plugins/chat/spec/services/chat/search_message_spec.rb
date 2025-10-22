# frozen_string_literal: true

RSpec.describe Chat::SearchMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:query) }
    it { is_expected.to allow_values(1, 40).for(:limit) }
    it { is_expected.not_to allow_values(0, 41, nil).for(:limit) }
    it { is_expected.to allow_values(0).for(:offset) }
    it { is_expected.not_to allow_values(-1).for(:offset) }
    it { is_expected.to validate_inclusion_of(:sort).in_array(%w[relevance latest]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :user)
    fab!(:channel, :chat_channel)

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { channel_id: channel.id, query: } }
    let(:dependencies) { { guardian: } }
    let(:query) { "test" }

    before do
      SearchIndexer.enable
      SiteSetting.chat_enabled = true
    end

    context "when contract is not valid" do
      let(:query) {}

      it { is_expected.to fail_a_contract }
    end

    context "when `channel_id` has been provided" do
      context "when the channel does not exist" do
        before { params[:channel_id] = 0 }

        it { is_expected.to fail_to_find_a_model(:channel) }
      end

      context "when the user cannot view the channel" do
        fab!(:channel, :direct_message_channel)

        it { is_expected.to fail_a_policy(:can_view_channel) }
      end
    end

    context "when everything is ok" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel, message: "test message") }

      before do
        channel.add(current_user)
        SearchIndexer.index(message, force: true)
        allow(Chat::Action::SearchForMessages).to receive(:call).and_call_original
      end

      it { is_expected.to run_successfully }

      it "searches for messages" do
        result
        expect(Chat::Action::SearchForMessages).to have_received(:call).with(
          params: an_instance_of(described_class::Contract),
          guardian:,
          channel:,
        )
      end

      it "returns metadata" do
        expect(result.metadata).to include(
          has_more: false,
          limit: 20,
          offset: 0,
          messages: [message],
        )
      end

      it "returns messages" do
        expect(result.messages).to contain_exactly(message)
      end
    end
  end
end
