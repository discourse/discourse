# frozen_string_literal: true

RSpec.describe Chat::RestoreMessage do
  fab!(:current_user) { Fabricate(:user) }
  let!(:guardian) { Guardian.new(current_user) }
  fab!(:message) { Fabricate(:chat_message, user: current_user) }

  before do
    message.trash!
    message.chat_channel.update!(
      last_message_id: message.chat_channel.latest_not_deleted_message_id,
    )
  end

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

      context "when the user does not have permission to restore" do
        before { message.update!(user: Fabricate(:admin)) }

        it { is_expected.to fail_a_policy(:invalid_access) }
      end

      context "when the channel does not match the message" do
        let(:params) do
          { guardian: guardian, message_id: message.id, channel_id: Fabricate(:chat_channel).id }
        end

        it { is_expected.to fail_to_find_a_model(:message) }
      end

      context "when the user has permission to restore" do
        it "sets the service result as successful" do
          expect(result).to be_a_success
        end

        it "restores the message" do
          result
          expect(Chat::Message.find_by(id: message.id)).not_to be_nil
        end

        it "updates the channel last_message_id if the message is now the last one in the channel" do
          expect(message.chat_channel.reload.last_message_id).to be_nil
          result
          expect(message.chat_channel.reload.last_message_id).to eq(message.id)
        end

        it "does not update the channel last_message_id if the message is not the last one in the channel" do
          next_message = Fabricate(:chat_message, chat_channel: message.chat_channel)
          message.chat_channel.update!(last_message: next_message)
          result
          expect(message.chat_channel.reload.last_message_id).to eq(next_message.id)
        end

        it "publishes associated Discourse and MessageBus events" do
          freeze_time
          messages = nil
          event =
            DiscourseEvent.track_events { messages = MessageBus.track_publish { result } }.first
          expect(event[:event_name]).to eq(:chat_message_restored)
          expect(event[:params]).to eq([message, message.chat_channel, current_user])
          expect(
            messages.find { |m| m.channel == "/chat/#{message.chat_channel_id}" }.data,
          ).to include({ "type" => "restore" })
        end

        context "when the message has a thread" do
          fab!(:thread) { Fabricate(:chat_thread, channel: message.chat_channel) }

          before do
            message.update!(thread: thread)
            thread.update_last_message_id!
            thread.original_message.update!(created_at: message.created_at - 2.hours)
          end

          it "increments the thread reply count" do
            thread.set_replies_count_cache(1)
            result
            expect(thread.replies_count_cache).to eq(2)
          end

          it "updates the thread last_message_id if the message is now the last one in the thread" do
            expect(message.thread.reload.last_message_id).to eq(thread.original_message_id)
            result
            expect(message.thread.reload.last_message_id).to eq(message.id)
          end

          it "does not update the thread last_message_id if the message is not the last one in the channel" do
            next_message =
              Fabricate(:chat_message, thread: message.thread, chat_channel: message.chat_channel)
            message.thread.update!(last_message: next_message)
            expect { result }.not_to change { message.thread.reload.last_message }
          end
        end
      end
    end
  end
end
