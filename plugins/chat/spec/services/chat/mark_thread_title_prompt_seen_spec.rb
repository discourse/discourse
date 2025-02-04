# frozen_string_literal: true

RSpec.describe Chat::MarkThreadTitlePromptSeen do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:private_channel) do
      Fabricate(:private_category_channel, group: Fabricate(:group), threading_enabled: true)
    end
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:last_reply) { Fabricate(:chat_message, thread: thread, chat_channel: channel) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { thread_id: thread.id, channel_id: thread.channel_id } }
    let(:dependencies) { { guardian: } }

    before { thread.update!(last_message: last_reply) }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      context "when the user is a member of the thread" do
        fab!(:membership) { thread.add(current_user) }

        it "updates the thread_title_prompt_seen" do
          expect { result }.not_to change { Chat::UserChatThreadMembership.count }
          expect(membership.reload.thread_title_prompt_seen).to eq(true)
        end
      end

      context "when the user is not a member of the thread yet" do
        it "creates the membership and updates thread_title_prompt_seen" do
          expect { result }.to change { Chat::UserChatThreadMembership.count }.by(1)
          expect(result.membership.thread_title_prompt_seen).to eq(true)
        end
      end
    end

    context "when thread_id is missing" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when channel_id is missing" do
      before { params.delete(:channel_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when thread is not found because the channel ID differs" do
      before { params[:thread_id] = Fabricate(:chat_thread).id }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when thread is not found" do
      before { thread.destroy! }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when threading is not enabled for the channel" do
      before { channel.update!(threading_enabled: false) }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
    end

    context "when user cannot see channel" do
      before { thread.update!(channel_id: private_channel.id) }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end
  end
end
