# frozen_string_literal: true

require "rails_helper"

describe Chat::ThreadUnreadsQuery do
  fab!(:channel_1) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:channel_2) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:thread_3) { Fabricate(:chat_thread, channel: channel_2) }
  fab!(:thread_4) { Fabricate(:chat_thread, channel: channel_2) }
  fab!(:current_user) { Fabricate(:user) }

  let(:params) { { user_id: current_user.id, channel_ids: channel_ids, thread_ids: thread_ids } }
  let(:include_missing_memberships) { false }
  let(:channel_ids) { [] }
  let(:thread_ids) { [] }
  let(:subject) do
    described_class.call(
      channel_ids: channel_ids,
      thread_ids: thread_ids,
      user_id: current_user.id,
      include_missing_memberships: include_missing_memberships,
    )
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
    channel_2.add(current_user)
    thread_1.add(current_user)
    thread_2.add(current_user)
    thread_3.add(current_user)
    thread_4.add(current_user)
  end

  context "with unread messages across multiple threads" do
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, thread: thread_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_2, thread: thread_3) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel_2, thread: thread_4) }

    context "when only the channel ids are provided" do
      let(:channel_ids) { [channel_1.id, channel_2.id] }

      it "gets a count of all the thread unreads across the channels" do
        expect(subject.map(&:to_h)).to match_array(
          [
            { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 1 },
            { channel_id: channel_1.id, mention_count: 0, thread_id: thread_2.id, unread_count: 0 },
            { channel_id: channel_2.id, mention_count: 0, thread_id: thread_3.id, unread_count: 1 },
            { channel_id: channel_2.id, mention_count: 0, thread_id: thread_4.id, unread_count: 1 },
          ],
        )
      end

      it "does not count deleted messages" do
        message_1.trash!
        expect(subject.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 0 },
        )
      end

      it "does not messages in threads where threading_enabled is false on the channel" do
        channel_1.update!(threading_enabled: false)
        expect(subject.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 0 },
        )
        expect(subject.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_2.id }).to eq(
          { channel_id: channel_1.id, mention_count: 0, thread_id: thread_2.id, unread_count: 0 },
        )
      end

      it "does not count as unread if the last_read_message_id is greater than or equal to the message id" do
        thread_1
          .user_chat_thread_memberships
          .find_by(user: current_user)
          .update!(last_read_message_id: message_1.id)
        expect(subject.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 0 },
        )
      end

      it "does not count the original message ID as unread" do
        thread_1.original_message.destroy
        thread_1.update!(original_message: message_1)
        expect(subject.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 0 },
        )
      end
    end

    context "when only the thread_ids are provided" do
      let(:thread_ids) { [thread_1.id, thread_3.id] }

      it "gets a count of all the thread unreads for the specified threads" do
        expect(subject.map(&:to_h)).to match_array(
          [
            { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 1 },
            { channel_id: channel_2.id, mention_count: 0, thread_id: thread_3.id, unread_count: 1 },
          ],
        )
      end

      context "when the notification_level for the thread is muted" do
        before do
          thread_1
            .user_chat_thread_memberships
            .find_by(user: current_user)
            .update!(notification_level: :muted)
        end

        it "gets a zeroed out count for the thread" do
          expect(subject.map(&:to_h)).to include(
            { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 0 },
          )
        end
      end

      context "when the user is not a member of a thread" do
        before { thread_1.user_chat_thread_memberships.find_by(user: current_user).destroy! }

        it "does not get that thread unread count by default" do
          expect(subject.map(&:to_h)).to match_array(
            [
              {
                channel_id: channel_2.id,
                mention_count: 0,
                thread_id: thread_3.id,
                unread_count: 1,
              },
            ],
          )
        end

        context "when include_missing_memberships is true" do
          let(:include_missing_memberships) { true }

          it "includes the thread that the user is not a member of with zeroed out counts" do
            expect(subject.map(&:to_h)).to match_array(
              [
                {
                  channel_id: channel_1.id,
                  mention_count: 0,
                  thread_id: thread_1.id,
                  unread_count: 0,
                },
                {
                  channel_id: channel_2.id,
                  mention_count: 0,
                  thread_id: thread_3.id,
                  unread_count: 1,
                },
              ],
            )
          end
        end
      end
    end

    context "when channel_ids and thread_ids are provided" do
      let(:channel_ids) { [channel_1.id, channel_2.id] }
      let(:thread_ids) { [thread_1.id, thread_3.id] }

      it "gets a count of all the thread unreads across the channels filtered by thread id" do
        expect(subject.map(&:to_h)).to match_array(
          [
            { channel_id: channel_1.id, mention_count: 0, thread_id: thread_1.id, unread_count: 1 },
            { channel_id: channel_2.id, mention_count: 0, thread_id: thread_3.id, unread_count: 1 },
          ],
        )
      end
    end
  end
end
