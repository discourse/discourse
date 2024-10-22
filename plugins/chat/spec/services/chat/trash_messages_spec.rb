# frozen_string_literal: true

RSpec.describe Chat::TrashMessages do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to allow_values([1], (1..200).to_a).for(:message_ids) }
    it { is_expected.not_to allow_values([], (1..201).to_a).for(:message_ids) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:chat_channel) { Fabricate(:chat_channel) }
    fab!(:message1) { Fabricate(:chat_message, user: current_user, chat_channel: chat_channel) }
    fab!(:message2) { Fabricate(:chat_message, user: current_user, chat_channel: chat_channel) }
    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_ids: [message1.id, message2.id], channel_id: chat_channel.id } }
    let(:dependencies) { { guardian: } }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when params are valid" do
      context "when the user does not have permission to delete" do
        before { message1.update!(user: Fabricate(:admin)) }

        it { is_expected.to fail_a_policy(:can_delete_all_chat_messages) }
      end

      context "when the channel does not match the message" do
        let(:params) do
          { message_ids: [message1.id, message2.id], channel_id: Fabricate(:chat_channel).id }
        end

        it { is_expected.to fail_to_find_a_model(:messages) }
      end

      context "when the user has permission to delete" do
        it { is_expected.to run_successfully }

        it "trashes the messages" do
          result
          [message1, message2].each do |message|
            expect(Chat::Message.find_by(id: message.id)).to be_nil

            deleted_message = Chat::Message.unscoped.find_by(id: message.id)
            expect(deleted_message.deleted_by_id).to eq(current_user.id)
            expect(deleted_message.deleted_at).to be_within(1.minute).of(Time.zone.now)
          end
        end

        it "destroys notifications for mentions" do
          mention1 =
            Fabricate(
              :user_chat_mention,
              chat_message: message1,
              notifications: [Fabricate(:notification)],
            )
          mention2 =
            Fabricate(
              :user_chat_mention,
              chat_message: message2,
              notifications: [Fabricate(:notification)],
            )

          result

          [mention1, mention2].each do |mention|
            mention = Chat::Mention.find_by(id: mention.id)
            expect(mention).to be_present
            expect(mention.notifications).to be_empty
          end
        end

        it "publishes associated Discourse and MessageBus events for multiple messages" do
          freeze_time
          messages = nil

          events =
            DiscourseEvent
              .track_events { messages = MessageBus.track_publish { result } }
              .select { |e| e[:event_name] == :chat_message_trashed }

          [message1, message2].each do |message|
            event = events.find { |e| e[:params].first.id == message.id }
            expect(event).to be_present
            expect(event[:params]).to eq([message, message.chat_channel, current_user])
          end

          message_data = messages.find { |m| m.channel == "/chat/#{chat_channel.id}" }.data
          expect(message_data).to eq(
            {
              "type" => "bulk_delete",
              "deleted_ids" => [message1.id, message2.id],
              "deleted_at" => message1.reload.deleted_at.iso8601(3),
            },
          )
        end

        it "updates the tracking to the last non-deleted channel message for users whose last_read_message_id was the trashed message" do
          other_message = Fabricate(:chat_message, chat_channel: chat_channel)
          membership_1 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: chat_channel,
              last_read_message: message1,
            )
          membership_2 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: chat_channel,
              last_read_message: message2,
            )
          membership_3 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: chat_channel,
              last_read_message: other_message,
            )
          result
          expect(membership_1.reload.last_read_message_id).to eq(other_message.id)
          expect(membership_2.reload.last_read_message_id).to eq(other_message.id)
          expect(membership_3.reload.last_read_message_id).to eq(other_message.id)
        end

        it "updates the tracking to nil when there are no other messages left in the channnel" do
          membership_1 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: chat_channel,
              last_read_message: message1,
            )
          membership_2 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: chat_channel,
              last_read_message: message2,
            )
          result
          expect(membership_1.reload.last_read_message_id).to be_nil
          expect(membership_2.reload.last_read_message_id).to be_nil
        end

        it "updates the channel last_message_id to the previous message in the channel" do
          message3 = Fabricate(:chat_message, chat_channel: chat_channel, user: current_user)
          params[:message_ids] = [message2.id, message3.id]
          chat_channel.update!(last_message: message3)
          result
          expect(chat_channel.reload.last_message).to eq(message1)
        end

        context "when the message has a thread" do
          fab!(:thread) { Fabricate(:chat_thread, channel: chat_channel) }

          before do
            message1.update!(thread: thread)
            message2.update!(thread: thread, created_at: message1.created_at - 1.hour)
            thread.update!(last_message: message1)
            thread.original_message.update!(created_at: message1.created_at - 2.hours)
          end

          it "decrements the thread reply count" do
            thread.set_replies_count_cache(5)
            result
            expect(thread.replies_count_cache).to eq(3)
          end

          it "updates the tracking to the last non-deleted thread message for users whose last_read_message_id was the trashed message" do
            other_message = Fabricate(:chat_message, chat_channel: chat_channel, thread: thread)
            membership_1 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message1)
            membership_2 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message2)
            membership_3 =
              Fabricate(
                :user_chat_thread_membership,
                thread: thread,
                last_read_message: other_message,
              )
            result
            expect(membership_1.reload.last_read_message_id).to eq(other_message.id)
            expect(membership_2.reload.last_read_message_id).to eq(other_message.id)
            expect(membership_3.reload.last_read_message_id).to eq(other_message.id)
          end

          it "updates the tracking to nil when there are no other messages left in the thread" do
            membership_1 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message1)
            membership_2 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message2)
            result
            expect(membership_1.reload.last_read_message_id).to be_nil
            expect(membership_2.reload.last_read_message_id).to be_nil
          end

          it "updates the thread last_message_id to the previous message in the thread" do
            next_message =
              Fabricate(
                :chat_message,
                thread: thread,
                user: current_user,
                chat_channel: chat_channel,
              )
            params[:message_ids] = [message2.id, next_message.id]
            thread.update!(last_message: next_message)
            result
            expect(thread.reload.last_message).to eq(message1)
          end

          context "when there are no other messages left in the thread except the original message" do
            it "updates the thread last_message_id to the original message" do
              expect(thread.last_message).to eq(message1)
              result
              expect(thread.reload.last_message).to eq(thread.original_message)
            end
          end
        end

        context "when all messages are already deleted" do
          before do
            message1.trash!
            message2.trash!
          end

          it { is_expected.to fail_to_find_a_model(:messages) }
        end
      end
    end
  end
end
