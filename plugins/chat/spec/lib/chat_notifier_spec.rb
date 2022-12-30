# frozen_string_literal: true

require "rails_helper"

describe Chat::ChatNotifier do
  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  fab!(:chat_group) do
    Fabricate(
      :group,
      users: [user_1, user_2],
      mentionable_level: Group::ALIAS_LEVELS[:everyone],
    )
  end

  fab!(:user_1_membership) { Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_1) }
  fab!(:user_2_membership) { Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_2) }

  before { SiteSetting.chat_allowed_groups = chat_group.id }

  def assert_users_were_notifier_with_mention_type(mention_type, user_ids)
    if user_ids.empty?
      expect(
        job_enqueued?(job: :chat_notify_mentioned, args: { mention_type: mention_type.to_s })
      ).to eq(false)
    else
      expect(
        job_enqueued?(job: :chat_notify_mentioned, args: { mention_type: mention_type.to_s, user_ids: user_ids })
      ).to eq(true)
    end
  end

  describe "#notify_new" do
    def build_cooked_msg(message_body, user, chat_channel: channel)
      ChatMessage.new(
        id: 1,
        chat_channel: chat_channel,
        user: user,
        message: message_body,
        created_at: 5.minutes.ago,
      ).tap(&:cook)
    end

    shared_examples "channel-wide mentions" do
      it "returns an empty list when the message doesn't include a channel mention" do
        msg = build_cooked_msg(mention.gsub("@", ""), user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [])
      end

      it "will never include someone who is not accepting channel-wide notifications" do
        user_2.user_option.update!(ignore_channel_wide_mention: true)
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [])
      end

      it "will never mention when channel is not accepting channel wide mentions" do
        channel.update!(allow_channel_wide_mentions: false)
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [])
      end

      it "includes all members of a channel except the sender" do
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id])
      end
    end

    shared_examples "ensure only channel members are notified" do
      it "will never include someone outside the channel" do
        user3 = Fabricate(:user)
        chat_group.add(user3)
        another_channel = Fabricate(:category_channel)
        Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user3)
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id])
      end

      it "will never include someone not following the channel anymore" do
        user3 = Fabricate(:user)
        chat_group.add(user3)
        Fabricate(
          :user_chat_channel_membership,
          following: false,
          chat_channel: channel,
          user: user3,
        )
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id])
      end

      it "will never include someone who is suspended" do
        user3 = Fabricate(:user, suspended_till: 2.years.from_now)
        chat_group.add(user3)
        Fabricate(
          :user_chat_channel_membership,
          following: true,
          chat_channel: channel,
          user: user3,
        )

        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id])
      end
    end

    describe "global_mentions" do
      let(:mention) { "hello @all!" }
      let(:list_key) { :global_mentions }

      include_examples "channel-wide mentions"
      include_examples "ensure only channel members are notified"
    end

    describe "here_mentions" do
      let(:mention) { "hello @here!" }
      let(:list_key) { :here_mentions }

      before { user_2.update!(last_seen_at: 4.minutes.ago) }

      include_examples "channel-wide mentions"
      include_examples "ensure only channel members are notified"

      it "includes users seen less than 5 minutes ago" do
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id])
      end

      it "excludes users seen more than 5 minutes ago" do
        user_2.update!(last_seen_at: 6.minutes.ago)
        msg = build_cooked_msg(mention, user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [])
      end

      it "excludes users mentioned directly" do
        msg = build_cooked_msg("hello @here @#{user_2.username}!", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [])
      end
    end

    describe "direct_mentions" do
      it "only include mentioned users who are already in the channel" do
        user_3 = Fabricate(:user)
        chat_group.add(user_3)
        another_channel = Fabricate(:category_channel)
        Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user_3)
        msg = build_cooked_msg("Is @#{user_3.username} here? And @#{user_2.username}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [user_2.id])
      end

      it "include users as direct mentions even if there's a @here mention" do
        msg = build_cooked_msg("Hello @here and @#{user_2.username}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:here_mentions, [])
        assert_users_were_notifier_with_mention_type(:direct_mentions, [user_2.id])
      end

      it "include users as direct mentions even if there's a @all mention" do
        msg = build_cooked_msg("Hello @all and @#{user_2.username}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:global_mentions, [])
        assert_users_were_notifier_with_mention_type(:direct_mentions, [user_2.id])
      end
    end

    describe "group mentions" do
      fab!(:user_3) { Fabricate(:user) }
      fab!(:group) do
        Fabricate(
          :public_group,
          users: [user_2, user_3],
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      end
      fab!(:other_channel) { Fabricate(:category_channel) }

      before { chat_group.add(user_3) }

      let(:mention) { "hello @#{group.name}!" }
      let(:list_key) { group.name }

      include_examples "ensure only channel members are notified"

      it 'calls guardian can_join_chat_channel?' do
        Guardian.any_instance.expects(:can_join_chat_channel?).at_least_once
        msg = build_cooked_msg("Hello @#{group.name} and @#{user_2.username}", user_1)
        described_class.new(msg, msg.created_at).notify_new
      end

      it "establishes a far-left precedence among group mentions" do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: channel,
          user: user_3,
          following: true,
        )
        msg = build_cooked_msg("Hello @#{chat_group.name} and @#{group.name}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(chat_group.name, [user_2.id, user_3.id])
        assert_users_were_notifier_with_mention_type(list_key, [])

        Jobs::ChatNotifyMentioned.clear
        second_msg = build_cooked_msg("Hello @#{group.name} and @#{chat_group.name}", user_1)

        to_notify_2 = described_class.new(second_msg, second_msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(list_key, [user_2.id, user_3.id])
        assert_users_were_notifier_with_mention_type(chat_group.name, [])
      end

      it "skips groups with too many members" do
        SiteSetting.max_users_notified_per_group_mention = (group.user_count - 1)

        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(group.name, [])
      end

      it "respects the 'max_mentions_per_chat_message' setting and skips notifications" do
        SiteSetting.max_mentions_per_chat_message = 1

        msg = build_cooked_msg("Hello @#{user_2.username} and @#{user_3.username}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [])
        assert_users_were_notifier_with_mention_type(group.name, [])
      end

      it "respects the max mentions setting and skips notifications when mixing users and groups" do
        SiteSetting.max_mentions_per_chat_message = 1

        msg = build_cooked_msg("Hello @#{user_2.username} and @#{group.name}", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [])
        assert_users_were_notifier_with_mention_type(group.name, [])
      end
    end

    describe "unreachable users" do
      fab!(:user_3) { Fabricate(:user) }

      it "notify poster of users who are not allowed to use chat" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        unreachable_msg = messages.first

        expect(unreachable_msg).to be_present
        expect(unreachable_msg.data[:without_membership]).to be_empty
        unreachable_users = unreachable_msg.data[:cannot_see].map { |u| u["id"] }
        expect(unreachable_users).to contain_exactly(user_3.id)
      end

      context "when in a personal message" do
        let(:personal_chat_channel) do
          Group.refresh_automatic_groups!
          Chat::DirectMessageChannelCreator.create!(
            acting_user: user_1,
            target_users: [user_1, user_2],
          )
        end

        before { chat_group.add(user_3) }

        it "notify posts of users who are not participating in a personal message" do
          msg =
            build_cooked_msg(
              "Hello @#{user_3.username}",
              user_1,
              chat_channel: personal_chat_channel,
            )

          messages =
            MessageBus.track_publish("/chat/#{personal_chat_channel.id}") do
              described_class.new(msg, msg.created_at).notify_new

              assert_users_were_notifier_with_mention_type(:direct_mentions, [])
            end

          unreachable_msg = messages.first

          expect(unreachable_msg).to be_present
          expect(unreachable_msg.data[:without_membership]).to be_empty
          unreachable_users = unreachable_msg.data[:cannot_see].map { |u| u["id"] }
          expect(unreachable_users).to contain_exactly(user_3.id)
        end
      end
    end

    describe "users who can be invited to join the channel" do
      fab!(:user_3) { Fabricate(:user) }

      before { chat_group.add(user_3) }

      it "can invite chat user without channel membership" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        not_participating_msg = messages.first

        expect(not_participating_msg).to be_present
        expect(not_participating_msg.data[:cannot_see]).to be_empty
        not_participating_users = not_participating_msg.data[:without_membership].map { |u| u["id"] }
        expect(not_participating_users).to contain_exactly(user_3.id)
      end

      it "cannot invite chat user without channel membership if they are ignoring the user who created the message" do
        Fabricate(:ignored_user, user: user_3, ignored_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        expect(messages).to be_empty
      end

      it "cannot invite chat user without channel membership if they are muting the user who created the message" do
        Fabricate(:muted_user, user: user_3, muted_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        expect(messages).to be_empty
      end

      it "can invite chat user who no longer follows the channel" do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: channel,
          user: user_3,
          following: false,
        )
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        not_participating_msg = messages.first

        expect(not_participating_msg).to be_present
        expect(not_participating_msg.data[:cannot_see]).to be_empty
        not_participating_users = not_participating_msg.data[:without_membership].map { |u| u["id"] }
        expect(not_participating_users).to contain_exactly(user_3.id)
      end

      it "cannot invite a member of a group who is ignoring the user who created the message" do
        group =
          Fabricate(
            :public_group,
            users: [user_2, user_3],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        Fabricate(:ignored_user, user: user_3, ignored_user: user_1, expiring_at: 1.day.from_now)
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        expect(messages).to be_empty
      end

      it "cannot invite a member of a group who is muting the user who created the message" do
        group =
          Fabricate(
            :public_group,
            users: [user_2, user_3],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        Fabricate(:muted_user, user: user_3, muted_user: user_1)
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            described_class.new(msg, msg.created_at).notify_new

            assert_users_were_notifier_with_mention_type(:direct_mentions, [])
          end

        expect(messages).to be_empty
      end
    end

    describe "enforcing limits when mentioning groups" do
      fab!(:user_3) { Fabricate(:user) }
      fab!(:group) do
        Fabricate(
          :public_group,
          users: [user_2, user_3],
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      end

      it "sends a message to the client signaling the group has too many members" do
        SiteSetting.max_users_notified_per_group_mention = (group.user_count - 1)
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") do
          described_class.new(msg, msg.created_at).notify_new

          assert_users_were_notifier_with_mention_type(group.name, [])
        end

        too_many_members_msg = messages.first
        expect(too_many_members_msg).to be_present
        too_many_members = too_many_members_msg.data[:groups_with_too_many_members]
        expect(too_many_members).to contain_exactly(group.name)
      end

      it "sends a message to the client signaling the group doesn't allow mentions" do
        group.update!(mentionable_level: Group::ALIAS_LEVELS[:only_admins])
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") do
          described_class.new(msg, msg.created_at).notify_new

          assert_users_were_notifier_with_mention_type(group.name, [])
        end

        mentions_disabled_msg = messages.first
        expect(mentions_disabled_msg).to be_present
        mentions_disabled = mentions_disabled_msg.data[:group_mentions_disabled]
        expect(mentions_disabled).to contain_exactly(group.name)
      end
    end

    describe "establishing a precedence between mention types" do
      before { user_2.update!(last_seen_at: 4.minutes.ago) }

      it "gives direct mentions the highest precedence" do
        msg = build_cooked_msg("@#{user_2.username} @#{chat_group.name} @here @all", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [user_2.id])
        assert_users_were_notifier_with_mention_type(chat_group.name, [])
        assert_users_were_notifier_with_mention_type(:here_mentions, [])
        assert_users_were_notifier_with_mention_type(:global_mentions, [])
      end

      it "gives group mentions the second highest precedence" do
        msg = build_cooked_msg("@#{chat_group.name} @here @all", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [])
        assert_users_were_notifier_with_mention_type(chat_group.name, [user_2.id])
        assert_users_were_notifier_with_mention_type(:here_mentions, [])
        assert_users_were_notifier_with_mention_type(:global_mentions, [])
      end

      it "gives here mentions the third highest precedence" do
        msg = build_cooked_msg("@here @all", user_1)

        described_class.new(msg, msg.created_at).notify_new

        assert_users_were_notifier_with_mention_type(:direct_mentions, [])
        assert_users_were_notifier_with_mention_type(chat_group.name, [])
        assert_users_were_notifier_with_mention_type(:here_mentions, [user_2.id])
        assert_users_were_notifier_with_mention_type(:global_mentions, [])
      end
    end
  end

  describe "#notify_edit" do
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: channel, user: user_1) }
    fab!(:user_2_mention) { Fabricate(:chat_mention, user: user_2, chat_message: chat_message) }

    def edit_msg(chat_message, new_body)
      chat_message.message = new_body
      chat_message.cook

      described_class.new(chat_message, chat_message.updated_at).notify_edit
    end

    describe "removing a mention from a message update existing mentions records" do
      it "deletes everything when removing all mentions" do
        edit_msg(chat_message, "No more mentions")

        expect { user_2_mention.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does nothing if the user still has access through a group" do
        edit_msg(chat_message, "Hello @#{chat_group.name}")

        expect { user_2_mention.reload }.not_to raise_error
      end

      it "removes the record when mentioning a different group" do
        group_2 = Fabricate(:group)
        edit_msg(chat_message, "Hello @#{group_2.name}")

        expect { user_2_mention.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does nothing when we keep the username mention" do
        edit_msg(chat_message, "Hello @#{user_2.username}")

        expect { user_2_mention.reload }.not_to raise_error
      end

      it "removes the mention when only mentioning a different user" do
        edit_msg(chat_message, "Hello @#{user_1.username}")

        expect { user_2_mention.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
