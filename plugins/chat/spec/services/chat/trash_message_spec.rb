# frozen_string_literal: true

RSpec.describe Chat::TrashMessage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:message_id) }
    it { is_expected.to validate_presence_of(:channel_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(**params, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:message) { Fabricate(:chat_message, user: current_user) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { message_id: message.id, channel_id: } }
    let(:dependencies) { { guardian: } }
    let(:channel_id) { message.chat_channel_id }

    context "when params are not valid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when params are valid" do
      context "when the user does not have permission to delete" do
        before { message.update!(user: Fabricate(:admin)) }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when the channel does not match the message" do
        let(:channel_id) { -1 }

        it { is_expected.to fail_to_find_a_model(:message) }
      end

      context "when the user has permission to delete" do
        it { is_expected.to run_successfully }

        it "trashes the message" do
          result
          expect(Chat::Message.find_by(id: message.id)).to be_nil

          deleted_message = Chat::Message.unscoped.find_by(id: message.id)
          expect(deleted_message.deleted_by_id).to eq(current_user.id)
          expect(deleted_message.deleted_at).to be_within(1.minute).of(Time.zone.now)
        end

        it "destroys notifications for mentions" do
          notification = Fabricate(:notification)
          mention =
            Fabricate(:user_chat_mention, chat_message: message, notifications: [notification])

          result

          mention = Chat::Mention.find_by(id: mention.id)
          expect(mention).to be_present
          expect(mention.notifications).to be_empty
        end

        it "publishes associated Discourse and MessageBus events" do
          freeze_time
          messages = nil
          event =
            DiscourseEvent
              .track_events { messages = MessageBus.track_publish { result } }
              .find { |e| e[:event_name] == :chat_message_trashed }

          expect(event).to be_present
          expect(event[:params]).to eq([message, message.chat_channel, current_user])
          expect(messages.find { |m| m.channel == "/chat/#{message.chat_channel_id}" }.data).to eq(
            {
              "type" => "delete",
              "deleted_id" => message.id,
              "deleted_by_id" => current_user.id,
              "deleted_at" => message.reload.deleted_at.iso8601(3),
              "latest_not_deleted_message_id" => nil,
            },
          )
        end

        it "updates the tracking to the last non-deleted channel message for users whose last_read_message_id was the trashed message" do
          other_message = Fabricate(:chat_message, chat_channel: message.chat_channel)
          membership_1 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: message.chat_channel,
              last_read_message: message,
            )
          membership_2 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: message.chat_channel,
              last_read_message: message,
            )
          membership_3 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: message.chat_channel,
              last_read_message: other_message,
            )
          result
          expect(membership_1.reload.last_read_message_id).to eq(other_message.id)
          expect(membership_2.reload.last_read_message_id).to eq(other_message.id)
          expect(membership_3.reload.last_read_message_id).to eq(other_message.id)
        end

        it "updates the tracking to nil when there are no other messages left in the channel" do
          membership_1 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: message.chat_channel,
              last_read_message: message,
            )
          membership_2 =
            Fabricate(
              :user_chat_channel_membership,
              chat_channel: message.chat_channel,
              last_read_message: message,
            )
          result
          expect(membership_1.reload.last_read_message_id).to be_nil
          expect(membership_2.reload.last_read_message_id).to be_nil
        end

        it "updates the channel last_message_id to the previous message in the channel" do
          next_message =
            Fabricate(:chat_message, chat_channel: message.chat_channel, user: current_user)
          params[:message_id] = next_message.id
          message.chat_channel.update!(last_message: next_message)
          result
          expect(message.chat_channel.reload.last_message).to eq(message)
        end

        context "when the message has a thread" do
          fab!(:thread) { Fabricate(:chat_thread, channel: message.chat_channel) }

          before do
            message.update!(thread: thread)
            thread.update!(last_message: message)
            thread.original_message.update!(created_at: message.created_at - 2.hours)
          end

          it "decrements the thread reply count" do
            thread.set_replies_count_cache(5)
            result
            expect(thread.replies_count_cache).to eq(4)
          end

          it "updates the tracking to the last non-deleted thread message for users whose last_read_message_id was the trashed message" do
            other_message =
              Fabricate(:chat_message, chat_channel: message.chat_channel, thread: thread)
            membership_1 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message)
            membership_2 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message)
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
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message)
            membership_2 =
              Fabricate(:user_chat_thread_membership, thread: thread, last_read_message: message)
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
                chat_channel: message.chat_channel,
              )
            params[:message_id] = next_message.id
            thread.update!(last_message: next_message)
            result
            expect(thread.reload.last_message).to eq(message)
          end

          context "when there are no other messages left in the thread except the original message" do
            it "updates the thread last_message_id to the original message" do
              expect(thread.last_message).to eq(message)
              result
              expect(thread.reload.last_message).to eq(thread.original_message)
            end
          end
        end

        context "when message is already deleted" do
          before { message.trash! }

          it { is_expected.to fail_to_find_a_model(:message) }
        end
      end
    end
  end
end
