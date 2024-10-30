# frozen_string_literal: true

describe Chat::Notifier do
  describe "#notify_new" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:user_2) { Fabricate(:user) }

    before do
      @chat_group =
        Fabricate(
          :group,
          users: [user_1, user_2],
          mentionable_level: Group::ALIAS_LEVELS[:everyone],
        )
      SiteSetting.chat_allowed_groups = @chat_group.id

      [user_1, user_2].each do |u|
        Fabricate(:user_chat_channel_membership, chat_channel: channel, user: u)
      end
    end

    def build_cooked_msg(message_body, user, chat_channel: channel)
      Chat::Message.create(
        chat_channel: chat_channel,
        user: user,
        message: message_body,
        created_at: 5.minutes.ago,
      ).tap(&:cook)
    end

    shared_examples "channel-wide mentions" do
      it "returns an empty list when the message doesn't include a channel mention" do
        msg = build_cooked_msg(mention.gsub("@", ""), user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to be_empty
      end

      it "will never include someone who is not accepting channel-wide notifications" do
        user_2.user_option.update!(ignore_channel_wide_mention: true)
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to be_empty
      end

      it "will never mention when channel is not accepting channel wide mentions" do
        channel.update!(allow_channel_wide_mentions: false)
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to be_empty
      end

      it "will publish a mention warning" do
        channel.update!(allow_channel_wide_mentions: false)
        msg = build_cooked_msg(mention, user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new
          end

        global_mentions_disabled_message = messages.first

        expect(global_mentions_disabled_message.data[:type].to_sym).to eq(:notice)
        expect(global_mentions_disabled_message.data[:text_content]).to eq(
          I18n.t("chat.mention_warning.global_mentions_disallowed"),
        )
      end

      it "includes all members of a channel except the sender" do
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to contain_exactly(user_2.id)
      end
    end

    shared_examples "ensure only channel members are notified" do
      it "will never include someone outside the channel" do
        user3 = Fabricate(:user)
        @chat_group.add(user3)
        another_channel = Fabricate(:category_channel)
        Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user3)
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to contain_exactly(user_2.id)
      end

      it "will never include someone not following the channel anymore" do
        user3 = Fabricate(:user)
        @chat_group.add(user3)
        Fabricate(
          :user_chat_channel_membership,
          following: false,
          chat_channel: channel,
          user: user3,
        )
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to contain_exactly(user_2.id)
      end

      it "will never include someone who is suspended" do
        user3 = Fabricate(:user, suspended_till: 2.years.from_now)
        @chat_group.add(user3)
        Fabricate(
          :user_chat_channel_membership,
          following: true,
          chat_channel: channel,
          user: user3,
        )

        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to contain_exactly(user_2.id)
      end
    end

    describe "global_mentions" do
      let(:mention) { "hello @all!" }
      let(:list_key) { :global_mentions }

      include_examples "channel-wide mentions"
      include_examples "ensure only channel members are notified"

      describe "editing a direct mention into a global mention" do
        let(:mention) { "hello @#{user_2.username}!" }

        it "doesn't send notifications with :all_mentioned_user_ids as an identifier" do
          Jobs.run_immediately!
          msg = build_cooked_msg(mention, user_1)

          Chat::UpdateMessage.call(
            guardian: user_1.guardian,
            params: {
              message_id: msg.id,
              message: "hello @all",
            },
          )

          described_class.new(msg, msg.created_at).notify_edit

          notifications = Notification.where(user: user_2)
          notifications.each do |notification|
            expect(notification.data).not_to include("\"identifier\":\"all_mentioned_user_ids\"")
          end
        end
      end

      describe "users ignoring or muting the user creating the message" do
        it "does not send notifications to the user who is muting the acting user" do
          Fabricate(:muted_user, user: user_2, muted_user: user_1)
          msg = build_cooked_msg(mention, user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[list_key]).to be_empty
        end

        it "does not send notifications to the user who is ignoring the acting user" do
          Fabricate(:ignored_user, user: user_2, ignored_user: user_1, expiring_at: 1.day.from_now)
          msg = build_cooked_msg(mention, user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
        end
      end
    end

    describe "here_mentions" do
      let(:mention) { "hello @here!" }
      let(:list_key) { :here_mentions }

      before { user_2.update!(last_seen_at: 4.minutes.ago) }

      include_examples "channel-wide mentions"
      include_examples "ensure only channel members are notified"

      it "includes users seen less than 5 minutes ago" do
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to contain_exactly(user_2.id)
      end

      it "excludes users seen more than 5 minutes ago" do
        user_2.update!(last_seen_at: 6.minutes.ago)
        msg = build_cooked_msg(mention, user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to be_empty
      end

      it "excludes users mentioned directly" do
        msg = build_cooked_msg("hello @here @#{user_2.username}!", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[list_key]).to be_empty
      end

      describe "users ignoring or muting the user creating the message" do
        it "does not send notifications to the user who is muting the acting user" do
          Fabricate(:muted_user, user: user_2, muted_user: user_1)
          msg = build_cooked_msg(mention, user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[list_key]).to be_empty
        end

        it "does not send notifications to the user who is ignoring the acting user" do
          Fabricate(:ignored_user, user: user_2, ignored_user: user_1, expiring_at: 1.day.from_now)
          msg = build_cooked_msg(mention, user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
        end
      end
    end

    describe "direct_mentions" do
      it "only include mentioned users who are already in the channel" do
        user_3 = Fabricate(:user)
        @chat_group.add(user_3)
        another_channel = Fabricate(:category_channel)
        Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user_3)
        msg = build_cooked_msg("Is @#{user_3.username} here? And @#{user_2.username}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[:direct_mentions]).to contain_exactly(user_2.id)
      end

      it "include users as direct mentions even if there's a @here mention" do
        msg = build_cooked_msg("Hello @here and @#{user_2.username}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[:here_mentions]).to be_empty
        expect(to_notify[:direct_mentions]).to contain_exactly(user_2.id)
      end

      it "include users as direct mentions even if there's a @all mention" do
        msg = build_cooked_msg("Hello @all and @#{user_2.username}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[:global_mentions]).to be_empty
        expect(to_notify[:direct_mentions]).to contain_exactly(user_2.id)
      end

      describe "users ignoring or muting the user creating the message" do
        it "does not publish new mentions to these users" do
          Fabricate(:muted_user, user: user_2, muted_user: user_1)
          msg = build_cooked_msg("hey @#{user_2.username} stop muting me!", user_1)

          Chat::Publisher.expects(:publish_new_mention).never
          to_notify = described_class.new(msg, msg.created_at).notify_new
        end

        it "does not send notifications to the user who is muting the acting user" do
          Fabricate(:muted_user, user: user_2, muted_user: user_1)
          msg = build_cooked_msg("hey @#{user_2.username} stop muting me!", user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
        end

        it "does not send notifications to the user who is ignoring the acting user" do
          Fabricate(:ignored_user, user: user_2, ignored_user: user_1, expiring_at: 1.day.from_now)
          msg = build_cooked_msg("hey @#{user_2.username} stop ignoring me!", user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
        end
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

      before { @chat_group.add(user_3) }

      let(:mention) { "hello @#{group.name}!" }
      let(:list_key) { group.name }

      include_examples "ensure only channel members are notified"

      it "calls guardian can_join_chat_channel?" do
        Guardian.any_instance.expects(:can_join_chat_channel?).at_least_once
        msg = build_cooked_msg("Hello @#{group.name} and @#{user_2.username}", user_1)
        to_notify = described_class.new(msg, msg.created_at).notify_new
      end

      it "establishes a far-left precedence among group mentions" do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: channel,
          user: user_3,
          following: true,
        )
        msg = build_cooked_msg("Hello @#{@chat_group.name} and @#{group.name}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[@chat_group.name]).to contain_exactly(user_2.id, user_3.id)
        expect(to_notify[list_key]).to be_empty

        second_msg = build_cooked_msg("Hello @#{group.name} and @#{@chat_group.name}", user_1)

        to_notify_2 = described_class.new(second_msg, second_msg.created_at).notify_new

        expect(to_notify_2[list_key]).to contain_exactly(user_2.id, user_3.id)
        expect(to_notify_2[@chat_group.name]).to be_empty
      end

      it "skips groups with too many members" do
        SiteSetting.max_users_notified_per_group_mention = (group.user_count - 1)

        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[group.name]).to be_nil
      end

      it "respects the 'max_mentions_per_chat_message' setting and skips notifications" do
        SiteSetting.max_mentions_per_chat_message = 1

        msg = build_cooked_msg("Hello @#{user_2.username} and @#{user_3.username}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[:direct_mentions]).to be_empty
        expect(to_notify[group.name]).to be_nil
      end

      it "respects the max mentions setting and skips notifications when mixing users and groups" do
        SiteSetting.max_mentions_per_chat_message = 1

        msg = build_cooked_msg("Hello @#{user_2.username} and @#{group.name}", user_1)

        to_notify = described_class.new(msg, msg.created_at).notify_new

        expect(to_notify[:direct_mentions]).to be_empty
        expect(to_notify[group.name]).to be_nil
      end

      describe "users ignoring or muting the user creating the message" do
        it "does not send notifications to the user inside the group who is muting the acting user" do
          group.add(user_3)
          Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_3)
          Fabricate(:muted_user, user: user_2, muted_user: user_1)
          msg = build_cooked_msg("Hello @#{group.name}", user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
          expect(to_notify[group.name]).to contain_exactly(user_3.id)
        end

        it "does not send notifications to the user inside the group who is ignoring the acting user" do
          group.add(user_3)
          Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_3)
          Fabricate(:ignored_user, user: user_2, ignored_user: user_1, expiring_at: 1.day.from_now)
          msg = build_cooked_msg("Hello @#{group.name}", user_1)

          to_notify = described_class.new(msg, msg.created_at).notify_new

          expect(to_notify[:direct_mentions]).to be_empty
          expect(to_notify[group.name]).to contain_exactly(user_3.id)
        end
      end
    end

    describe "unreachable users" do
      fab!(:user_3) { Fabricate(:user) }

      it "notify poster of users who are not allowed to use chat" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
          end

        unreachable_msg = messages.first

        expect(unreachable_msg[:data][:type].to_sym).to eq(:notice)
        expect(unreachable_msg[:data][:text_content]).to eq(
          I18n.t("chat.mention_warning.cannot_see", first_identifier: user_3.username),
        )
      end

      context "when in a personal message" do
        let(:personal_chat_channel) do
          result =
            Chat::CreateDirectMessageChannel.call(
              guardian: user_1.guardian,
              params: {
                target_usernames: [user_1.username, user_2.username],
              },
            )
          service_failed!(result) if result.failure?
          result.channel
        end

        before { @chat_group.add(user_3) }

        it "notify posts of users who are not participating in a personal message" do
          msg =
            build_cooked_msg(
              "Hello @#{user_3.username}",
              user_1,
              chat_channel: personal_chat_channel,
            )

          messages =
            MessageBus.track_publish("/chat/#{personal_chat_channel.id}") do
              to_notify = described_class.new(msg, msg.created_at).notify_new

              expect(to_notify[:direct_mentions]).to be_empty
            end

          unreachable_msg = messages.first

          expect(unreachable_msg[:data][:type].to_sym).to eq(:notice)
          expect(unreachable_msg[:data][:text_content]).to eq(
            I18n.t("chat.mention_warning.cannot_see", first_identifier: user_3.username),
          )
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
            MessageBus.track_publish("/chat/#{personal_chat_channel.id}") do
              to_notify = described_class.new(msg, msg.created_at).notify_new

              expect(to_notify[group.name]).to contain_exactly(user_2.id)
            end

          unreachable_msg = messages.first

          expect(unreachable_msg[:data][:type].to_sym).to eq(:notice)
          expect(unreachable_msg[:data][:text_content]).to eq(
            I18n.t("chat.mention_warning.cannot_see", first_identifier: user_3.username),
          )
        end
      end
    end

    describe "users who can be invited to join the channel" do
      fab!(:user_3) { Fabricate(:user) }

      before { @chat_group.add(user_3) }

      it "can invite chat user without channel membership" do
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
          end

        not_participating_msg = messages.first

        expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
        expect(not_participating_msg[:data][:text_content]).to be_nil
        expect(not_participating_msg[:data][:notice_type].to_sym).to eq(:mention_without_membership)
        expect(not_participating_msg[:data][:data]).to eq(
          user_ids: [user_3.id],
          text:
            I18n.t("chat.mention_warning.without_membership", first_identifier: user_3.username),
          message_id: msg.id,
        )
      end

      it "cannot invite chat user without channel membership if they are ignoring the user who created the message" do
        Fabricate(:ignored_user, user: user_3, ignored_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
          end

        expect(messages).to be_empty
      end

      it "cannot invite chat user without channel membership if they are muting the user who created the message" do
        Fabricate(:muted_user, user: user_3, muted_user: user_1)
        msg = build_cooked_msg("Hello @#{user_3.username}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
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
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
          end

        not_participating_msg = messages.first

        expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
        expect(not_participating_msg[:data][:text_content]).to be_nil
        expect(not_participating_msg[:data][:notice_type].to_sym).to eq(:mention_without_membership)
        expect(not_participating_msg[:data][:data]).to eq(
          user_ids: [user_3.id],
          text:
            I18n.t("chat.mention_warning.without_membership", first_identifier: user_3.username),
          message_id: msg.id,
        )
      end

      it "can invite other group members to channel" do
        group =
          Fabricate(
            :public_group,
            users: [user_2, user_3],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
          end

        not_participating_msg = messages.first

        expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
        expect(not_participating_msg[:data][:text_content]).to be_nil
        expect(not_participating_msg[:data][:notice_type].to_sym).to eq(:mention_without_membership)
        expect(not_participating_msg[:data][:data]).to eq(
          user_ids: [user_3.id],
          text:
            I18n.t("chat.mention_warning.without_membership", first_identifier: user_3.username),
          message_id: msg.id,
        )
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
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
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
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[:direct_mentions]).to be_empty
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

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[group.name]).to be_nil
          end

        too_many_members_msg = messages.first

        expect(too_many_members_msg[:data][:type].to_sym).to eq(:notice)
        expect(too_many_members_msg[:data][:text_content]).to eq(
          I18n.t("chat.mention_warning.too_many_members", first_identifier: group.name),
        )
      end

      it "sends a message to the client signaling the group doesn't allow mentions" do
        group.update!(mentionable_level: Group::ALIAS_LEVELS[:only_admins])
        msg = build_cooked_msg("Hello @#{group.name}", user_1)

        messages =
          MessageBus.track_publish("/chat/#{channel.id}") do
            to_notify = described_class.new(msg, msg.created_at).notify_new

            expect(to_notify[group.name]).to be_nil
          end

        mentions_disabled_msg = messages.first

        expect(mentions_disabled_msg[:data][:type].to_sym).to eq(:notice)
        expect(mentions_disabled_msg[:data][:text_content]).to eq(
          I18n.t("chat.mention_warning.group_mentions_disabled", first_identifier: group.name),
        )
      end
    end
  end
end
