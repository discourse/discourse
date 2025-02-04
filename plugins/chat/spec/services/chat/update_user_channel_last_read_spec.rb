# frozen_string_literal: true

RSpec.describe Chat::UpdateUserChannelLastRead do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :message_id }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:chatters) { Fabricate(:group) }
    fab!(:current_user) { Fabricate(:user, group_ids: [chatters.id]) }
    fab!(:channel) { Fabricate(:chat_channel) }
    let(:membership) do
      Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
    end
    let(:message_1) { Fabricate(:chat_message, chat_channel: membership.chat_channel) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { channel_id: channel.id, message_id: message_1.id } }
    let(:dependencies) { { guardian: } }

    before { SiteSetting.chat_allowed_groups = chatters }

    context "when params are not valid" do
      before { params.delete(:message_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when params are valid" do
      context "when user has no membership" do
        before { membership.destroy! }

        it { is_expected.to fail_to_find_a_model(:membership) }
      end

      context "when user can’t access the channel" do
        fab!(:membership) do
          Fabricate(
            :user_chat_channel_membership,
            user: current_user,
            chat_channel: Fabricate(:private_category_channel),
          )
        end

        before { params[:channel_id] = membership.chat_channel.id }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when message_id is older than membership's last_read_message_id" do
        before do
          message_old = Fabricate(:chat_message, chat_channel: channel)
          message_new = Fabricate(:chat_message, chat_channel: channel)
          params[:message_id] = message_old.id
          membership.update!(last_read_message_id: message_new.id)
        end

        it { is_expected.to fail_a_policy(:ensure_message_id_recency) }
      end

      context "when message doesn’t exist" do
        before do
          message = Fabricate(:chat_message)
          params[:message_id] = message.id
          message.trash!
          membership.update!(last_read_message_id: 1)
        end

        it { is_expected.to fail_to_find_a_model(:message) }
      end

      context "when everything is fine" do
        fab!(:notification) do
          Fabricate(
            :notification,
            notification_type: Notification.types[:chat_mention],
            user: current_user,
          )
        end

        let(:messages) { MessageBus.track_publish { result } }

        before do
          Jobs.run_immediately!
          Chat::UserMention.create!(
            notifications: [notification],
            user: current_user,
            chat_message: message_1,
          )
        end

        it { is_expected.to run_successfully }

        it "updates the last_read message id" do
          expect { result }.to change { membership.reload.last_read_message_id }.to(message_1.id)
        end

        it "marks existing notifications related to the message as read" do
          expect { result }.to change {
            Notification.where(
              notification_type: Notification.types[:chat_mention],
              user: current_user,
              read: false,
            ).count
          }.by(-1)
        end

        it "publishes new last read to clients" do
          expect(messages.map(&:channel)).to include("/chat/user-tracking-state/#{current_user.id}")
        end

        it "updates the channel membership last_viewed_at datetime" do
          membership.update!(last_viewed_at: 1.day.ago)
          old_last_viewed_at = membership.last_viewed_at
          result
          expect(membership.reload.last_viewed_at).not_to eq_time(old_last_viewed_at)
        end
      end
    end
  end
end
