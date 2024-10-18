# frozen_string_literal: true

RSpec.describe Chat::LookupThread do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:private_channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:other_thread) { Fabricate(:chat_thread) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { thread_id: thread.id, channel_id: thread.channel_id } }
    let(:dependencies) { { guardian: } }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "fetches the thread" do
        expect(result.thread).to eq(thread)
      end
    end

    context "when params are not valid" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when thread is not found because the channel ID differs" do
      before { params[:thread_id] = other_thread.id }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when thread is not found" do
      before { thread.destroy! }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when user cannot see channel" do
      before { thread.update!(channel: private_channel) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when threading is not enabled for the channel" do
      before { channel.update!(threading_enabled: false) }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }

      context "when thread is forced" do
        before { thread.update!(force: true) }

        it { is_expected.to run_successfully }
      end
    end
  end
end
