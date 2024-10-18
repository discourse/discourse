# frozen_string_literal: true

RSpec.describe Chat::UpdateThreadNotificationSettings do
  describe described_class::Contract, type: :model do
    let(:notification_levels) { Chat::UserChatThreadMembership.notification_levels.values }

    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
    it { is_expected.to validate_presence_of :notification_level }
    it { is_expected.to validate_inclusion_of(:notification_level).in_array(notification_levels) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:private_channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:last_reply) { Fabricate(:chat_message, thread: thread, chat_channel: channel) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) do
      {
        guardian: guardian,
        thread_id: thread.id,
        channel_id: thread.channel_id,
        notification_level: Chat::UserChatThreadMembership.notification_levels[:normal],
      }
    end

    before { thread.update!(last_message: last_reply) }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      context "when the user is a member of the thread" do
        fab!(:membership) { thread.add(current_user) }

        it "updates the notification_level" do
          expect { result }.not_to change { Chat::UserChatThreadMembership.count }
          expect(membership.reload.notification_level).to eq("normal")
        end
      end

      context "when the user is not a member of the thread yet" do
        it "creates the membership and sets the last read message id to the last reply" do
          expect { result }.to change { Chat::UserChatThreadMembership.count }.by(1)
          expect(result.membership.notification_level).to eq("normal")
          expect(result.membership.last_read_message_id).to eq(last_reply.id)
        end
      end
    end

    context "when params are not valid" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when notification_level is not valid" do
      before { params[:notification_level] = 100 }

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

    context "when user cannot see channel" do
      before { thread.update!(channel: private_channel) }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end

    context "when threading is not enabled for the channel" do
      before { channel.update!(threading_enabled: false) }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
    end
  end
end
