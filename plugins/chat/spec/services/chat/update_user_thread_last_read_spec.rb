# frozen_string_literal: true

RSpec.describe Chat::UpdateUserThreadLastRead do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :thread_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:chatters) { Fabricate(:group) }
    fab!(:current_user) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:thread) { Fabricate(:chat_thread, old_om: true) }
    fab!(:reply_1) { Fabricate(:chat_message, thread: thread, chat_channel_id: thread.channel.id) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_id: reply_1.id, channel_id: thread.channel.id, thread_id: thread.id } }
    let(:dependencies) { { guardian: } }

    before do
      thread.add(current_user)
      SiteSetting.chat_allowed_groups = chatters
    end

    context "when params are not valid" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when thread cannot be found" do
      before { params[:channel_id] = Fabricate(:chat_channel).id }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when user has no membership" do
      before { thread.remove(current_user) }

      it { is_expected.to fail_to_find_a_model(:membership) }
    end

    context "when user can’t access the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

      it { is_expected.to fail_a_policy(:invalid_access) }
    end

    context "when params are valid" do
      it { is_expected.to run_successfully }

      it "publishes new last read to clients" do
        messages = MessageBus.track_publish { result }
        expect(messages.map(&:channel)).to include("/chat/user-tracking-state/#{current_user.id}")
      end

      context "when the user is a member of the thread" do
        fab!(:membership) do
          Fabricate(:user_chat_thread_membership, user: current_user, thread: thread)
        end

        it "updates the last_read_message_id of the thread" do
          expect { result }.to change { membership.reload.last_read_message_id }.from(nil).to(
            reply_1.id,
          )
        end

        context "when the provided last read id is before the existing one" do
          fab!(:reply_2) { Fabricate(:chat_message, thread: thread) }

          before { thread.membership_for(current_user).update!(last_read_message_id: reply_2.id) }

          it { is_expected.to fail_a_policy(:ensure_valid_message) }
        end

        context "when the message doesn’t exist" do
          it "fails" do
            params[:message_id] = 999
            is_expected.to fail_to_find_a_model(:message)
          end
        end
      end
    end

    context "when unread messages have associated notifications" do
      before_all do
        Jobs.run_immediately!
        thread.channel.add(current_user)
      end

      fab!(:reply_2) do
        Fabricate(
          :chat_message,
          thread: thread,
          message: "hi @#{current_user.username}",
          use_service: true,
        )
      end

      fab!(:reply_3) do
        Fabricate(
          :chat_message,
          thread: thread,
          message: "hi @#{current_user.username}",
          use_service: true,
        )
      end

      it "marks notifications as read" do
        params[:message_id] = reply_2.id

        expect { described_class.call(params:, **dependencies) }.to change {
          ::Notification
            .where(notification_type: Notification.types[:chat_mention])
            .where(user: current_user)
            .where(read: false)
            .count
        }.by(-1)

        params[:message_id] = reply_3.id

        expect { described_class.call(params:, **dependencies) }.to change {
          ::Notification
            .where(notification_type: Notification.types[:chat_mention])
            .where(user: current_user)
            .where(read: false)
            .count
        }.by(-1)
      end
    end
  end
end
