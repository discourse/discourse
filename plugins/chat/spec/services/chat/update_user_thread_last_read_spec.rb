# frozen_string_literal: true

RSpec.describe Chat::UpdateUserThreadLastRead do
  describe Chat::UpdateUserThreadLastRead::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_reply_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }
    fab!(:thread_reply_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { guardian: guardian, channel_id: channel.id, thread_id: thread.id } }

    context "when params are not valid" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when params are valid" do
      context "when user can’t access the channel" do
        fab!(:channel) { Fabricate(:private_category_channel) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when thread cannot be found" do
        before { params[:channel_id] = Fabricate(:chat_channel).id }

        it { is_expected.to fail_to_find_a_model(:thread) }
      end

      context "when everything is fine" do
        fab!(:notification_1) do
          Fabricate(
            :notification,
            notification_type: Notification.types[:chat_mention],
            user: current_user,
          )
        end
        fab!(:notification_2) do
          Fabricate(
            :notification,
            notification_type: Notification.types[:chat_mention],
            user: current_user,
          )
        end

        let(:messages) { MessageBus.track_publish { result } }

        before do
          Jobs.run_immediately!
          Chat::Mention.create!(
            notification: notification_1,
            user: current_user,
            chat_message: Fabricate(:chat_message, chat_channel: channel, thread: thread),
          )
          Chat::Mention.create!(
            notification: notification_2,
            user: current_user,
            chat_message: Fabricate(:chat_message, chat_channel: channel, thread: thread),
          )
        end

        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

        it "marks existing notifications related to all messages in the thread as read" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:chat_mention],
              user: current_user,
              read: false,
            ).count
          }.by(-2)
        end

        it "publishes new last read to clients" do
          expect(messages.map(&:channel)).to include("/chat/user-tracking-state/#{current_user.id}")
        end

        context "when the user is a member of the thread" do
          fab!(:membership) do
            Fabricate(:user_chat_thread_membership, user: current_user, thread: thread)
          end

          it "updates the last_read_message_id of the thread" do
            result
            expect(membership.reload.last_read_message_id).to eq(thread.replies.last.id)
          end
        end
      end
    end
  end
end
