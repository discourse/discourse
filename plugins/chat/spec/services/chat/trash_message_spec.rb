# frozen_string_literal: true

RSpec.describe Chat::TrashMessage do
  fab!(:current_user) { Fabricate(:user) }
  let!(:guardian) { Guardian.new(current_user) }
  fab!(:message) { Fabricate(:chat_message, user: current_user) }

  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "when params are not valid" do
      let(:params) { { guardian: guardian } }

      it { is_expected.to fail_a_contract }
    end

    context "when params are valid" do
      let(:params) do
        { guardian: guardian, message_id: message.id, channel_id: message.chat_channel_id }
      end

      context "when the user does not have permission to delete" do
        before { message.update!(user: Fabricate(:admin)) }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when the channel does not match the message" do
        let(:params) do
          { guardian: guardian, message_id: message.id, channel_id: Fabricate(:chat_channel).id }
        end

        it { is_expected.to fail_to_find_a_model(:message) }
      end

      context "when the user has permission to delete" do
        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

        it "trashes the message" do
          result
          expect(Chat::Message.find_by(id: message.id)).to be_nil
        end

        it "destroys associated mentions" do
          mention = Fabricate(:chat_mention, chat_message: message)
          result
          expect(Chat::Mention.find_by(id: mention.id)).to be_nil
        end

        it "publishes associated Discourse and MessageBus events" do
          freeze_time
          messages = nil
          event =
            DiscourseEvent.track_events { messages = MessageBus.track_publish { result } }.first
          expect(event[:event_name]).to eq(:chat_message_trashed)
          expect(event[:params]).to eq([message, message.chat_channel, current_user])
          expect(messages.find { |m| m.channel == "/chat/#{message.chat_channel_id}" }.data).to eq(
            {
              "type" => "delete",
              "deleted_id" => message.id,
              "deleted_at" => message.reload.deleted_at.iso8601(3),
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

        it "updates the tracking to nil when there are no other messages left in the channnel" do
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

        context "when the message has a thread" do
          fab!(:thread) { Fabricate(:chat_thread, channel: message.chat_channel) }

          before { message.update!(thread: thread) }

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
        end

        context "when message is already deleted" do
          before { message.trash! }

          it { is_expected.to fail_to_find_a_model(:message) }
        end
      end
    end
  end
end
