# frozen_string_literal: true

RSpec.describe Chat::LookupThread do
  describe Chat::LookupThread::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:private_channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:other_thread) { Fabricate(:chat_thread) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: thread.channel_id } }

    context "when enable_experimental_chat_threaded_discussions is disabled" do
      before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

      it { is_expected.to fail_a_policy(:threaded_discussions_enabled) }
    end

    context "when enable_experimental_chat_threaded_discussions is enabled" do
      before { SiteSetting.enable_experimental_chat_threaded_discussions = true }

      context "when all steps pass" do
        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

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
      end
    end
  end
end
