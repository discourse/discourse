# frozen_string_literal: true

describe Chat::ChannelUnreadsQuery do
  subject(:query) do
    described_class.call(
      channel_ids: channel_ids,
      user_id: current_user.id,
      include_missing_memberships: include_missing_memberships,
      include_read: include_read,
    ).map(&:to_h)
  end

  fab!(:channel_1) { Fabricate(:category_channel) }
  fab!(:current_user) { Fabricate(:user) }
  let(:include_missing_memberships) { false }
  let(:include_read) { true }
  let(:channel_ids) { [channel_1.id] }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel_1.add(current_user)
  end

  context "with unread message" do
    before { Fabricate(:chat_message, chat_channel: channel_1) }

    it "returns a correct unread count" do
      expect(query.first).to eq(
        {
          mention_count: 0,
          unread_count: 1,
          channel_id: channel_1.id,
          watched_threads_unread_count: 0,
        },
      )
    end

    context "when the membership has been muted" do
      before do
        channel_1
          .user_chat_channel_memberships
          .find_by(user_id: current_user.id)
          .update!(muted: true)
      end

      it "returns a zeroed unread count" do
        expect(query.first).to eq(
          {
            mention_count: 0,
            unread_count: 0,
            channel_id: channel_1.id,
            watched_threads_unread_count: 0,
          },
        )
      end
    end

    context "for unread messages in a thread" do
      fab!(:thread_om) { Fabricate(:chat_message, chat_channel: channel_1) }
      fab!(:thread) { Fabricate(:chat_thread, channel: channel_1, original_message: thread_om) }

      it "does include the original message in the unread count" do
        expect(query.first).to eq(
          {
            mention_count: 0,
            unread_count: 2,
            watched_threads_unread_count: 0,
            channel_id: channel_1.id,
          },
        )
      end

      it "does not include other thread messages in the unread count" do
        Fabricate(:chat_message, chat_channel: channel_1, thread: thread)
        Fabricate(:chat_message, chat_channel: channel_1, thread: thread)
        expect(query.first).to eq(
          {
            mention_count: 0,
            unread_count: 2,
            watched_threads_unread_count: 0,
            channel_id: channel_1.id,
          },
        )
      end
    end

    context "for multiple channels" do
      fab!(:channel_2) { Fabricate(:category_channel) }
      let(:channel_ids) { [channel_1.id, channel_2.id] }

      before do
        channel_2.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_2)
        Fabricate(:chat_message, chat_channel: channel_2)
      end

      it "returns accurate counts" do
        expect(query).to match_array(
          [
            {
              mention_count: 0,
              unread_count: 1,
              watched_threads_unread_count: 0,
              channel_id: channel_1.id,
            },
            {
              mention_count: 0,
              unread_count: 2,
              watched_threads_unread_count: 0,
              channel_id: channel_2.id,
            },
          ],
        )
      end

      context "for channels where the user has no membership" do
        before do
          current_user
            .user_chat_channel_memberships
            .where(chat_channel_id: channel_2.id)
            .destroy_all
        end

        it "does not return counts for the channels" do
          expect(query).to match_array(
            [
              {
                mention_count: 0,
                unread_count: 1,
                watched_threads_unread_count: 0,
                channel_id: channel_1.id,
              },
            ],
          )
        end

        context "when include_missing_memberships is true" do
          let(:include_missing_memberships) { true }

          it "does return zeroed counts for the channels" do
            expect(query).to match_array(
              [
                {
                  mention_count: 0,
                  unread_count: 1,
                  watched_threads_unread_count: 0,
                  channel_id: channel_1.id,
                },
                {
                  mention_count: 0,
                  unread_count: 0,
                  watched_threads_unread_count: 0,
                  channel_id: channel_2.id,
                },
              ],
            )
          end

          context "when include_read is false" do
            let(:include_read) { false }

            it "does not return counts for the channels" do
              expect(query).to match_array(
                [
                  {
                    mention_count: 0,
                    unread_count: 1,
                    watched_threads_unread_count: 0,
                    channel_id: channel_1.id,
                  },
                ],
              )
            end
          end
        end
      end
    end
  end

  context "with unread mentions" do
    before { Jobs.run_immediately! }

    def create_mention(message, channel)
      notification =
        Notification.create!(
          notification_type: Notification.types[:chat_mention],
          user_id: current_user.id,
          data: { chat_message_id: message.id, chat_channel_id: channel.id }.to_json,
        )
      Chat::UserMention.create!(
        notifications: [notification],
        user: current_user,
        chat_message: message,
      )
    end

    it "returns a correct unread mention" do
      message = Fabricate(:chat_message, chat_channel: channel_1)
      create_mention(message, channel_1)

      expect(query.first).to eq(
        {
          mention_count: 1,
          unread_count: 1,
          watched_threads_unread_count: 0,
          channel_id: channel_1.id,
        },
      )
    end

    context "for unread mentions in a thread" do
      fab!(:thread_om) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
      fab!(:thread) { Fabricate(:chat_thread, channel: channel_1, original_message: thread_om) }

      it "does include the original message in the mention count" do
        create_mention(thread_om, channel_1)
        expect(query.first).to eq(
          {
            mention_count: 1,
            unread_count: 1,
            watched_threads_unread_count: 0,
            channel_id: channel_1.id,
          },
        )
      end

      it "includes thread messages with mentions in the channel mention count" do
        thread_message_1 = Fabricate(:chat_message, chat_channel: channel_1, thread: thread)
        thread_message_2 = Fabricate(:chat_message, chat_channel: channel_1, thread: thread)
        create_mention(thread_message_1, channel_1)
        create_mention(thread_message_2, channel_1)

        expect(query.first).to eq(
          {
            mention_count: 2,
            unread_count: 1,
            watched_threads_unread_count: 0,
            channel_id: channel_1.id,
          },
        )
      end
    end

    context "for multiple channels" do
      fab!(:channel_2) { Fabricate(:category_channel) }
      let(:channel_ids) { [channel_1.id, channel_2.id] }

      it "returns accurate counts" do
        message = Fabricate(:chat_message, chat_channel: channel_1)
        create_mention(message, channel_1)

        channel_2.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_2)
        message_2 = Fabricate(:chat_message, chat_channel: channel_2)
        create_mention(message_2, channel_2)

        expect(query).to match_array(
          [
            {
              mention_count: 1,
              unread_count: 1,
              watched_threads_unread_count: 0,
              channel_id: channel_1.id,
            },
            {
              mention_count: 1,
              unread_count: 2,
              watched_threads_unread_count: 0,
              channel_id: channel_2.id,
            },
          ],
        )
      end
    end
  end

  context "with watched threads" do
    fab!(:message) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel_1, original_message: message) }
    fab!(:thread_reply) { Fabricate(:chat_message, chat_channel: channel_1, thread: thread) }

    before do
      channel_1.update(threading_enabled: true)
      channel_1.membership_for(current_user).mark_read!(message.id)
      thread.membership_for(current_user).update!(
        notification_level: ::Chat::NotificationLevels.all[:watching],
      )
    end

    it "returns correct watched thread unread count" do
      expect(query.first).to eq(
        {
          mention_count: 0,
          unread_count: 0,
          watched_threads_unread_count: 1,
          channel_id: channel_1.id,
        },
      )
    end

    it "returns unread and watched thread unread counts" do
      Fabricate(:chat_message, chat_channel: channel_1)
      expect(query.first).to eq(
        {
          mention_count: 0,
          unread_count: 1,
          watched_threads_unread_count: 1,
          channel_id: channel_1.id,
        },
      )
    end

    context "for multiple channels" do
      fab!(:channel_2) { Fabricate(:category_channel) }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_2, user: current_user) }
      fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_2, original_message: message_2) }
      let(:channel_ids) { [channel_1.id, channel_2.id] }

      before do
        channel_2.add(current_user)
        channel_2.update(threading_enabled: true)
        channel_2.membership_for(current_user).mark_read!(message_2.id)
        thread_2.membership_for(current_user).update!(
          notification_level: ::Chat::NotificationLevels.all[:watching],
        )

        Fabricate(:chat_message, chat_channel: channel_2, thread: thread_2)
        Fabricate(:chat_message, chat_channel: channel_2, thread: thread_2)
      end

      it "returns accurate counts" do
        expect(query).to match_array(
          [
            {
              mention_count: 0,
              unread_count: 0,
              watched_threads_unread_count: 1,
              channel_id: channel_1.id,
            },
            {
              mention_count: 0,
              unread_count: 0,
              watched_threads_unread_count: 2,
              channel_id: channel_2.id,
            },
          ],
        )
      end
    end
  end

  context "with nothing unread" do
    it "returns a correct state" do
      expect(query.first).to eq(
        {
          mention_count: 0,
          unread_count: 0,
          watched_threads_unread_count: 0,
          channel_id: channel_1.id,
        },
      )
    end

    context "when include_read is false" do
      let(:include_read) { false }

      it "returns nothing" do
        expect(query).to eq([])
      end
    end
  end
end
