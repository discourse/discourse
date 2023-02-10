# frozen_string_literal: true

require "rails_helper"

describe Chat::MessageMentionWarnings do
  def build_cooked_msg(message_body, user, chat_channel: channel)
    ChatMessage.new(
      chat_channel: chat_channel,
      user: user,
      message: message_body,
      created_at: 5.minutes.ago,
    ).tap(&:cook)
  end

  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:chat_group) do
    Fabricate(:group, users: [user_1, user_2], mentionable_level: Group::ALIAS_LEVELS[:everyone])
  end

  before do
    SiteSetting.chat_allowed_groups = chat_group.id

    [user_1, user_2].each do |u|
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: u)
    end
  end

  describe "#dispatch" do
    context "when mentioned users are unreachable" do
      it "notify poster of users who are not allowed to use chat" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        unreachable_msg = messages.first.data[:warnings].detect { |m| m[:type] == :cannot_see }

        expect(unreachable_msg).to be_present
        unreachable_users = unreachable_msg[:mentions]
        expect(unreachable_users).to contain_exactly(user_3.username)
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
            MessageBus.track_publish("/chat/#{personal_chat_channel.id}") { subject.dispatch(msg) }

          unreachable_msg = messages.first.data[:warnings].detect { |m| m[:type] == :cannot_see }

          expect(unreachable_msg).to be_present
          unreachable_users = unreachable_msg[:mentions]
          expect(unreachable_users).to contain_exactly(user_3.username)
        end

        it "notify posts of users who are part of the mentioned group but participating" do
          group =
            Fabricate(
              :public_group,
              users: [user_2, user_3],
              mentionable_level: Group::ALIAS_LEVELS[:everyone],
            )
          msg =
            build_cooked_msg("Hello @#{group.name}", user_1, chat_channel: personal_chat_channel)

          messages =
            MessageBus.track_publish("/chat/#{personal_chat_channel.id}") { subject.dispatch(msg) }

          unreachable_msg = messages.first.data[:warnings].detect { |m| m[:type] == :cannot_see }

          expect(unreachable_msg).to be_present
          unreachable_users = unreachable_msg[:mentions]
          expect(unreachable_users).to contain_exactly(user_3.username)
        end
      end
    end

    context "when we can invite mentioned users to the channel" do
      before { chat_group.add(user_3) }

      it "can invite chat user without channel membership" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        non_participating_msg =
          messages.first.data[:warnings].detect { |m| m[:type] == :without_membership }

        expect(non_participating_msg).to be_present
        non_participating_usernames = non_participating_msg[:mentions]
        expect(non_participating_usernames).to contain_exactly(user_3.username)
        non_participating_user_ids = non_participating_msg[:mention_target_ids]
        expect(non_participating_user_ids).to contain_exactly(user_3.id)
      end

      it "cannot invite chat user without channel membership if they are ignoring the user who created the message" do
        Fabricate(:ignored_user, user: user_3, ignored_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        expect(messages).to be_empty
      end

      it "cannot invite chat user without channel membership if they are muting the user who created the message" do
        Fabricate(:muted_user, user: user_3, muted_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

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

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        not_participating_msg =
          messages.first.data[:warnings].detect { |m| m[:type] == :without_membership }

        expect(not_participating_msg).to be_present
        non_participating_usernames = not_participating_msg[:mentions]
        expect(non_participating_usernames).to contain_exactly(user_3.username)
        non_participating_user_ids = not_participating_msg[:mention_target_ids]
        expect(non_participating_user_ids).to contain_exactly(user_3.id)
      end

      it "can invite other group members to channel" do
        group =
          Fabricate(
            :public_group,
            users: [user_2, user_3],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        not_participating_msg =
          messages.first.data[:warnings].detect { |m| m[:type] == :without_membership }

        expect(not_participating_msg).to be_present
        non_participating_usernames = not_participating_msg[:mentions]
        expect(non_participating_usernames).to contain_exactly(user_3.username)
        non_participating_user_ids = not_participating_msg[:mention_target_ids]
        expect(non_participating_user_ids).to contain_exactly(user_3.id)
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

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

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

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        expect(messages).to be_empty
      end
    end

    describe "enforcing limits when mentioning groups" do
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

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        too_many_members_msg =
          messages.first.data[:warnings].detect { |m| m[:type] == :too_many_members }

        expect(too_many_members_msg).to be_present
        too_many_members = too_many_members_msg[:mentions]
        expect(too_many_members).to contain_exactly(group.name)
      end

      it "sends a message to the client signaling the group doesn't allow mentions" do
        group.update!(mentionable_level: Group::ALIAS_LEVELS[:only_admins])
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages = MessageBus.track_publish("/chat/#{channel.id}") { subject.dispatch(msg) }

        mentions_disabled_msg =
          messages.first.data[:warnings].detect { |m| m[:type] == :group_mentions_disabled }

        expect(mentions_disabled_msg).to be_present
        mentions_disabled = mentions_disabled_msg[:mentions]
        expect(mentions_disabled).to contain_exactly(group.name)
      end
    end
  end
end
