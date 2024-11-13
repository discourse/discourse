# frozen_string_literal: true

describe Chat::ThreadUnreadsQuery do
  subject(:query) do
    described_class.call(
      channel_ids: channel_ids,
      thread_ids: thread_ids,
      user_id: current_user.id,
      include_missing_memberships: include_missing_memberships,
      include_read: include_read,
    )
  end

  fab!(:channel_1) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:channel_2) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_1) }
  fab!(:thread_3) { Fabricate(:chat_thread, channel: channel_2) }
  fab!(:thread_4) { Fabricate(:chat_thread, channel: channel_2) }
  fab!(:current_user) { Fabricate(:user) }

  let(:params) { { user_id: current_user.id, channel_ids: channel_ids, thread_ids: thread_ids } }
  let(:include_missing_memberships) { false }
  let(:include_read) { true }
  let(:channel_ids) { [] }
  let(:thread_ids) { [] }

  before do
    SiteSetting.chat_enabled = true
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
        expect(query.map(&:to_h)).to match_array(
          [
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_1.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_2.id,
              unread_count: 0,
              watched_threads_unread_count: 0,
            },
            {
              channel_id: channel_2.id,
              mention_count: 0,
              thread_id: thread_3.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
            {
              channel_id: channel_2.id,
              mention_count: 0,
              thread_id: thread_4.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
          ],
        )
      end

      it "does not count deleted messages" do
        message_1.trash!
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "does not count messages in muted channels" do
        channel_1.membership_for(current_user).update!(muted: true)

        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "does not messages in threads where threading_enabled is false on the channel" do
        channel_1.update!(threading_enabled: false)
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_2.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_2.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "does not count as unread if the last_read_message_id is greater than or equal to the message id" do
        thread_1
          .user_chat_thread_memberships
          .find_by(user: current_user)
          .update!(last_read_message_id: message_1.id)
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "does not count the original message ID as unread" do
        thread_1.original_message.destroy
        thread_1.update!(original_message: message_1)
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "does not count the thread as unread if the original message is deleted" do
        thread_1.original_message.destroy
        expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
          {
            channel_id: channel_1.id,
            mention_count: 0,
            thread_id: thread_1.id,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      context "when include_read is false" do
        let(:include_read) { false }

        it "does not get threads with no unread messages" do
          expect(query.map(&:to_h)).not_to include(
            [
              {
                channel_id: channel_1.id,
                mention_count: 0,
                thread_id: thread_2.id,
                unread_count: 0,
                watched_threads_unread_count: 0,
              },
            ],
          )
        end
      end

      context "with mentions" do
        let!(:message) { create_mention(message_1, channel_1, thread_1) }

        def create_mention(message, channel, thread)
          notification =
            Notification.create!(
              notification_type: Notification.types[:chat_mention],
              user_id: current_user.id,
              data: {
                chat_message_id: message.id,
                chat_channel_id: channel.id,
                thread_id: thread.id,
              }.to_json,
            )
          Chat::UserMention.create!(
            notifications: [notification],
            user: current_user,
            chat_message: message,
          )
        end

        it "counts both unread messages and mentions separately" do
          expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
            {
              thread_id: thread_1.id,
              channel_id: channel_1.id,
              unread_count: 1,
              mention_count: 1,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "does not count mentions in muted channels" do
          channel_1.membership_for(current_user).update!(muted: true)

          expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
            {
              thread_id: thread_1.id,
              channel_id: channel_1.id,
              unread_count: 0,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "does not count mentions in threads when channel has threading_enabled = false" do
          channel_1.update!(threading_enabled: false)

          expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
            {
              thread_id: thread_1.id,
              channel_id: channel_1.id,
              unread_count: 0,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "does not count mentions in threads when the message is deleted" do
          message_1.trash!

          expect(query.map(&:to_h).find { |tracking| tracking[:thread_id] == thread_1.id }).to eq(
            {
              thread_id: thread_1.id,
              channel_id: channel_1.id,
              unread_count: 0,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end
      end
    end

    context "when only the thread_ids are provided" do
      let(:thread_ids) { [thread_1.id, thread_3.id] }

      it "gets a count of all the thread unreads for the specified threads" do
        expect(query.map(&:to_h)).to match_array(
          [
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_1.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
            {
              channel_id: channel_2.id,
              mention_count: 0,
              thread_id: thread_3.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
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
          expect(query.map(&:to_h)).to include(
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_1.id,
              unread_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end
      end

      context "when the notification_level for the thread is normal" do
        before do
          thread_1
            .user_chat_thread_memberships
            .find_by(user: current_user)
            .update!(notification_level: :normal)
        end

        it "gets a zeroed out count for the thread" do
          expect(query.map(&:to_h)).to include(
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_1.id,
              unread_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "still counts mentions" do
          create_thread_mention(thread: thread_1)

          expect(query.map(&:to_h)).to include(
            {
              channel_id: channel_1.id,
              mention_count: 1,
              thread_id: thread_1.id,
              unread_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end
      end

      context "when the user is not a member of a thread" do
        before { thread_1.user_chat_thread_memberships.find_by(user: current_user).destroy! }

        it "does not get that thread unread count by default" do
          expect(query.map(&:to_h)).to match_array(
            [
              {
                channel_id: channel_2.id,
                mention_count: 0,
                thread_id: thread_3.id,
                unread_count: 1,
                watched_threads_unread_count: 0,
              },
            ],
          )
        end

        context "when include_missing_memberships is true" do
          let(:include_missing_memberships) { true }

          it "includes the thread that the user is not a member of with zeroed out counts" do
            expect(query.map(&:to_h)).to match_array(
              [
                {
                  channel_id: channel_1.id,
                  mention_count: 0,
                  thread_id: thread_1.id,
                  unread_count: 0,
                  watched_threads_unread_count: 0,
                },
                {
                  channel_id: channel_2.id,
                  mention_count: 0,
                  thread_id: thread_3.id,
                  unread_count: 1,
                  watched_threads_unread_count: 0,
                },
              ],
            )
          end

          context "when include_read is false" do
            let(:include_read) { false }

            it "does not include the thread that the user is not a member of with zeroed out counts" do
              expect(query.map(&:to_h)).to match_array(
                [
                  {
                    channel_id: channel_2.id,
                    mention_count: 0,
                    thread_id: thread_3.id,
                    unread_count: 1,
                    watched_threads_unread_count: 0,
                  },
                ],
              )
            end
          end
        end
      end
    end

    context "when channel_ids and thread_ids are provided" do
      let(:channel_ids) { [channel_1.id, channel_2.id] }
      let(:thread_ids) { [thread_1.id, thread_3.id] }

      it "gets a count of all the thread unreads across the channels filtered by thread id" do
        expect(query.map(&:to_h)).to match_array(
          [
            {
              channel_id: channel_1.id,
              mention_count: 0,
              thread_id: thread_1.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
            {
              channel_id: channel_2.id,
              mention_count: 0,
              thread_id: thread_3.id,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
          ],
        )
      end
    end
  end

  context "with watched threads" do
    let(:channel_ids) { [channel_1.id] }

    before do
      [thread_1, thread_3].each do |thread|
        thread.membership_for(current_user).update!(
          notification_level: Chat::NotificationLevels.all[:watching],
        )
      end

      3.times { Fabricate(:chat_message, chat_channel: channel_1, thread: thread_1) }
      2.times { Fabricate(:chat_message, chat_channel: channel_1, thread: thread_2) }
    end

    it "returns correct count for channel" do
      expect(query.map(&:to_h)).to match_array(
        [
          {
            channel_id: channel_1.id,
            thread_id: thread_1.id,
            mention_count: 0,
            unread_count: 0,
            watched_threads_unread_count: 3,
          },
          {
            channel_id: channel_1.id,
            thread_id: thread_2.id,
            mention_count: 0,
            unread_count: 2,
            watched_threads_unread_count: 0,
          },
        ],
      )
    end

    it "returns correct count across multiple channels" do
      channel_ids.push(channel_2.id)
      Fabricate(:chat_message, chat_channel: channel_2, thread: thread_3)

      expect(query.map(&:to_h)).to match_array(
        [
          {
            channel_id: channel_1.id,
            thread_id: thread_1.id,
            mention_count: 0,
            unread_count: 0,
            watched_threads_unread_count: 3,
          },
          {
            channel_id: channel_1.id,
            thread_id: thread_2.id,
            mention_count: 0,
            unread_count: 2,
            watched_threads_unread_count: 0,
          },
          {
            channel_id: channel_2.id,
            thread_id: thread_3.id,
            mention_count: 0,
            unread_count: 0,
            watched_threads_unread_count: 1,
          },
          {
            channel_id: channel_2.id,
            thread_id: thread_4.id,
            mention_count: 0,
            unread_count: 0,
            watched_threads_unread_count: 0,
          },
        ],
      )
    end

    context "when include_read is false" do
      let(:include_read) { false }

      it "does not get threads with no unread messages" do
        expect(query.map(&:to_h)).to include(
          {
            channel_id: channel_1.id,
            thread_id: thread_1.id,
            mention_count: 0,
            unread_count: 0,
            watched_threads_unread_count: 3,
          },
        )
      end
    end
  end
end
