# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::AutoJoinChannelBatch do
  describe "#execute" do
    fab!(:category) { Fabricate(:category) }
    let!(:user) { Fabricate(:user, last_seen_at: 15.minutes.ago) }
    let(:channel) { Fabricate(:chat_channel, auto_join_users: true, chatable: category) }

    it "joins all valid users in the batch" do
      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_users_follows_channel(channel, [user])
    end

    it "doesn't join users outside the batch" do
      another_user = Fabricate(:user, last_seen_at: 15.minutes.ago)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_users_follows_channel(channel, [user])
      assert_user_skipped(channel, another_user)
    end

    it "doesn't join suspended users" do
      user.update!(suspended_till: 1.year.from_now)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_user_skipped(channel, user)
    end

    it "doesn't join users last_seen more than 3 months ago" do
      user.update!(last_seen_at: 4.months.ago)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_user_skipped(channel, user)
    end

    it "joins users with last_seen set to null" do
      user.update!(last_seen_at: nil)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_users_follows_channel(channel, [user])
    end

    it "does nothing if the channel is invalid" do
      subject.execute(chat_channel_id: -1, starts_at: user.id, ends_at: user.id)

      assert_user_skipped(channel, user)
    end

    it "does nothing if the channel chatable is not a category" do
      direct_message = Fabricate(:direct_message)
      channel.update!(chatable: direct_message)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_user_skipped(channel, user)
    end

    it "enqueues the user count update job and marks the channel user count as stale" do
      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: channel.id,
        },
      )

      expect(channel.reload.user_count_stale).to eq(true)
    end

    it "does not enqueue the user count update job or mark the channel user count as stale when there is more than use user" do
      user_2 = Fabricate(:user)
      expect_not_enqueued_with(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: channel.id,
        },
      ) { subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user_2.id) }

      expect(channel.reload.user_count_stale).to eq(false)
    end

    it "ignores users without chat_enabled" do
      user.user_option.update!(chat_enabled: false)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      assert_user_skipped(channel, user)
    end

    it "sets the join reason to automatic" do
      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

      new_membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
      expect(new_membership.automatic?).to eq(true)
    end

    it "skips anonymous users" do
      user_2 = Fabricate(:anonymous)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user_2.id)

      assert_users_follows_channel(channel, [user])
      assert_user_skipped(channel, user_2)
    end

    it "skips non-active users" do
      user_2 = Fabricate(:user, active: false, last_seen_at: 15.minutes.ago)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user_2.id)

      assert_users_follows_channel(channel, [user])
      assert_user_skipped(channel, user_2)
    end

    it "skips staged users" do
      user_2 = Fabricate(:user, staged: true, last_seen_at: 15.minutes.ago)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user_2.id)

      assert_users_follows_channel(channel, [user])
      assert_user_skipped(channel, user_2)
    end

    it "adds every user in the batch" do
      user_2 = Fabricate(:user, last_seen_at: 15.minutes.ago)

      subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user_2.id)

      assert_users_follows_channel(channel, [user, user_2])
    end

    it "publishes a message only to joined users" do
      messages =
        MessageBus.track_publish("/chat/new-channel") do
          subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.data.dig(:channel, :id)).to eq(channel.id)
    end

    describe "context when the channel's category is read restricted" do
      fab!(:chatters_group) { Fabricate(:group) }
      let(:private_category) { Fabricate(:private_category, group: chatters_group) }
      let(:channel) { Fabricate(:chat_channel, auto_join_users: true, chatable: private_category) }

      before { chatters_group.add(user) }

      it "only joins group members with access to the category" do
        another_user = Fabricate(:user, last_seen_at: 15.minutes.ago)

        subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: another_user.id)

        assert_users_follows_channel(channel, [user])
        assert_user_skipped(channel, another_user)
      end

      it "works if the user has access through more than one group" do
        second_chatters_group = Fabricate(:group)
        Fabricate(:category_group, category: category, group: second_chatters_group)
        second_chatters_group.add(user)

        subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: user.id)

        assert_users_follows_channel(channel, [user])
      end

      it "joins every user with access to the category" do
        another_user = Fabricate(:user, last_seen_at: 15.minutes.ago)
        chatters_group.add(another_user)

        subject.execute(chat_channel_id: channel.id, starts_at: user.id, ends_at: another_user.id)

        assert_users_follows_channel(channel, [user, another_user])
      end

      it "doesn't join users with read-only access to the category" do
        restricted_category = Fabricate(:category, read_restricted: true)
        another_user = Fabricate(:user, last_seen_at: 15.minutes.ago)
        non_chatters_group = Fabricate(:group)
        readonly_channel =
          Fabricate(:category_channel, chatable: restricted_category, auto_join_users: true)
        Fabricate(
          :category_group,
          category: restricted_category,
          group: non_chatters_group,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        non_chatters_group.add(another_user)

        subject.execute(
          chat_channel_id: readonly_channel.id,
          starts_at: another_user.id,
          ends_at: another_user.id,
        )

        assert_user_skipped(readonly_channel, another_user)
      end

      it "does join users with at least one group with create_post or full permission" do
        restricted_category = Fabricate(:category, read_restricted: true)
        another_user = Fabricate(:user, last_seen_at: 15.minutes.ago)
        non_chatters_group = Fabricate(:group)
        private_channel =
          Fabricate(:category_channel, chatable: restricted_category, auto_join_users: true)
        Fabricate(
          :category_group,
          category: restricted_category,
          group: non_chatters_group,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        non_chatters_group.add(another_user)

        other_group = Fabricate(:group)
        Fabricate(
          :category_group,
          category: restricted_category,
          group: other_group,
          permission_type: CategoryGroup.permission_types[:create_post],
        )
        other_group.add(another_user)

        subject.execute(
          chat_channel_id: private_channel.id,
          starts_at: another_user.id,
          ends_at: another_user.id,
        )

        assert_users_follows_channel(private_channel, [another_user])
      end
    end
  end

  def assert_users_follows_channel(channel, users)
    new_memberships = Chat::UserChatChannelMembership.where(user: users, chat_channel: channel)
    expect(new_memberships.length).to eq(users.length)
    expect(new_memberships.all?(&:following)).to eq(true)
  end

  def assert_user_skipped(channel, user)
    new_membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
    expect(new_membership).to be_nil
  end
end
