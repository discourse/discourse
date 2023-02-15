# frozen_string_literal: true

RSpec.describe Chat::Service::LookupThread do
  describe Chat::Service::LookupThread::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }

    let(:guardian) { Guardian.new(current_user) }

    context "when enable_experimental_chat_threaded_discussions is disabled" do
      let(:params) { { thread_id: 999, channel_id: 999 } }

      before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

      it { is_expected.to fail_a_policy(:threaded_discussions_enabled) }
    end

    context "when enable_experimental_chat_threaded_discussions is enabled" do
      before { SiteSetting.enable_experimental_chat_threaded_discussions = true }

      context "when all steps pass" do
        fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: thread.channel_id } }

        it "is successful" do
          expect(result).to be_a_success
          expect(result.thread).to eq(thread)
        end
      end

      context "when params are not valid" do
        let(:params) { {} }

        it { is_expected.to fail_a_contract }
      end

      context "when thread is not found because the channel ID differs" do
        fab!(:thread) { Fabricate(:chat_thread) }
        fab!(:channel) { Fabricate(:chat_channel) }

        let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: channel.id } }

        it { is_expected.to fail_to_find_a_model(:thread) }
      end

      context "when thread is not found" do
        fab!(:channel) { Fabricate(:chat_channel) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        before { thread.destroy! }

        let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: thread.channel_id } }

        it { is_expected.to fail_to_find_a_model(:thread) }
      end

      context "when user cannot see channel" do
        fab!(:channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: thread.channel_id } }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when threading is not enabled for the channel" do
        fab!(:channel) { Fabricate(:chat_channel) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        let(:params) { { guardian: guardian, thread_id: thread.id, channel_id: thread.channel_id } }

        it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
      end
    end
  end
end
