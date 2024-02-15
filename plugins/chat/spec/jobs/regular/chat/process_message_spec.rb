# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::ProcessMessage do
  fab!(:chat_message) { Fabricate(:chat_message, message: "https://discourse.org/team") }

  it "updates cooked with oneboxes" do
    stub_request(:get, "https://discourse.org/team").to_return(
      status: 200,
      body: "<html><head><title>a</title></head></html>",
    )

    stub_request(:head, "https://discourse.org/team").to_return(status: 200)

    described_class.new.execute(chat_message_id: chat_message.id)
    expect(chat_message.reload.cooked).to eq(
      "<p><a href=\"https://discourse.org/team\" class=\"onebox\" target=\"_blank\" rel=\"noopener nofollow ugc\">https://discourse.org/team</a></p>",
    )
  end

  context "when the cooked message changed" do
    it "publishes the update" do
      chat_message.update!(cooked: "another lovely cat")
      Chat::Publisher.expects(:publish_processed!).once
      described_class.new.execute(chat_message_id: chat_message.id)
    end
  end

  it "does not error when message is deleted" do
    chat_message.destroy
    expect { described_class.new.execute(chat_message_id: chat_message.id) }.not_to raise_exception
  end

  context "with notifications (former notifier_spec.rb)" do
    # andrei fixme test edited messages too
    describe "with new messages" do
      fab!(:channel) { Fabricate(:category_channel) }
      fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:user_2) { Fabricate(:user) }

      before do
        Jobs.run_immediately!

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
        it "doesn't create notifications when the message doesn't include a channel mention" do
          msg = build_cooked_msg(mention.gsub("@", ""), user_1)
          described_class.new.execute(chat_message_id: msg.id)
          expect(Notification.count).to be(0)
        end

        it "will never notify someone who is not accepting channel-wide notifications" do
          user_2.user_option.update!(ignore_channel_wide_mention: true)
          msg = build_cooked_msg(mention, user_1)
          Fabricate(mention_type, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.count).to be(0)
        end

        it "doesn't create notifications when a channel is not accepting channel wide mentions" do
          channel.update!(allow_channel_wide_mentions: false)
          msg = build_cooked_msg(mention, user_1)
          Fabricate(mention_type, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.count).to be(0)
        end

        it "publishes a mention warning" do
          channel.update!(allow_channel_wide_mentions: false)
          msg = build_cooked_msg(mention, user_1)
          Fabricate(mention_type, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
            end

          global_mentions_disabled_message = messages.first

          expect(global_mentions_disabled_message.data[:type].to_sym).to eq(:notice)
          expect(global_mentions_disabled_message.data[:text_content]).to eq(
            I18n.t("chat.mention_warning.global_mentions_disallowed"),
          )
        end

        it "notifies all members of a channel except the sender" do
          msg = build_cooked_msg(mention, user_1)
          Fabricate(mention_type, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_1).count).to be(0)
          expect(Notification.where(user: user_2).count).to be(1)
        end
      end

      shared_examples "ensure only channel members are notified" do
        it "will never notify someone outside the channel" do
          user_3 = Fabricate(:user)
          @chat_group.add(user_3)
          another_channel = Fabricate(:category_channel)
          Fabricate(:user_chat_channel_membership, chat_channel: another_channel, user: user_3)

          msg = build_cooked_msg(mention, user_1)
          if mention_type == :group_chat_mention
            Fabricate(mention_type, group: group, chat_message: msg)
          else
            Fabricate(mention_type, chat_message: msg)
          end

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_3).count).to be(0)
        end

        it "will never notify someone not following the channel anymore" do
          user_3 = Fabricate(:user)
          @chat_group.add(user_3)
          Fabricate(
            :user_chat_channel_membership,
            following: false,
            chat_channel: channel,
            user: user_3,
          )

          msg = build_cooked_msg(mention, user_1)
          if mention_type == :group_chat_mention
            Fabricate(mention_type, group: group, chat_message: msg)
          else
            Fabricate(mention_type, chat_message: msg)
          end

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_3).count).to be(0)
        end

        it "will never notify someone who is suspended" do
          user_3 = Fabricate(:user, suspended_till: 2.years.from_now)
          @chat_group.add(user_3)
          Fabricate(
            :user_chat_channel_membership,
            following: true,
            chat_channel: channel,
            user: user_3,
          )

          msg = build_cooked_msg(mention, user_1)
          if mention_type == :group_chat_mention
            Fabricate(mention_type, group: group, chat_message: msg)
          else
            Fabricate(mention_type, chat_message: msg)
          end

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_3).count).to be(0)
        end
      end

      describe "global_mentions" do
        let(:mention) { "hello @all!" }
        let(:mention_type) { :all_chat_mention } # fixme andrei, super-hacky but this supports shared examples above
        let(:list_key) { :global_mentions }

        include_examples "channel-wide mentions"
        include_examples "ensure only channel members are notified"

        describe "editing a direct mention into a global mention" do
          let(:mention) { "hello @#{user_2.username}!" }

          it "doesn't send notifications with :all_mentioned_user_ids as an identifier" do
            msg = build_cooked_msg(mention, user_1)

            Chat::UpdateMessage.call(
              guardian: user_1.guardian,
              message_id: msg.id,
              message: "hello @all",
            )

            described_class.new.execute(chat_message_id: msg.id)

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
            Fabricate(:all_chat_mention, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
          end

          it "does not send notifications to the user who is ignoring the acting user" do
            Fabricate(
              :ignored_user,
              user: user_2,
              ignored_user: user_1,
              expiring_at: 1.day.from_now,
            )
            msg = build_cooked_msg(mention, user_1)
            Fabricate(:all_chat_mention, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
          end
        end
      end

      describe "here_mentions" do
        let(:mention) { "hello @here!" }
        let(:mention_type) { :here_chat_mention } # fixme andrei, super-hacky but this supports shared examples above
        let(:list_key) { :here_mentions }

        before { user_2.update!(last_seen_at: 4.minutes.ago) }

        include_examples "channel-wide mentions"
        include_examples "ensure only channel members are notified"

        it "includes users seen less than 5 minutes ago" do
          msg = build_cooked_msg(mention, user_1)
          Fabricate(:here_chat_mention, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_2).count).to be(1)
        end

        it "excludes users seen more than 5 minutes ago" do
          user_2.update!(last_seen_at: 6.minutes.ago)
          msg = build_cooked_msg(mention, user_1)
          Fabricate(:here_chat_mention, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_2).count).to be(0)
        end

        it "doesn't create two notifications if a user has been reached both by a @here and a direct mention" do
          msg = build_cooked_msg("hello @here and @#{user_2.username}", user_1)
          Fabricate(:here_chat_mention, chat_message: msg)
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_2).count).to be(1)
        end

        describe "users ignoring or muting the user creating the message" do
          it "does not send notifications to the user who is muting the acting user" do
            Fabricate(:muted_user, user: user_2, muted_user: user_1)
            msg = build_cooked_msg(mention, user_1)
            Fabricate(:here_chat_mention, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
          end

          it "does not send notifications to the user who is ignoring the acting user" do
            Fabricate(
              :ignored_user,
              user: user_2,
              ignored_user: user_1,
              expiring_at: 1.day.from_now,
            )
            msg = build_cooked_msg(mention, user_1)
            Fabricate(:here_chat_mention, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
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
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_2).count).to be(1)
        end

        it "doesn't create two notifications if a user has been reached both by a @all and a direct mention" do
          msg = build_cooked_msg("Hello @all and @#{user_2.username}", user_1)
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.where(user: user_2).count).to be(1)
        end

        describe "users ignoring or muting the user creating the message" do
          it "does not publish new mentions to these users" do
            Fabricate(:muted_user, user: user_2, muted_user: user_1)
            msg = build_cooked_msg("hey @#{user_2.username} stop muting me!", user_1)
            Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

            Chat::Publisher.expects(:publish_new_mention).never
            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
          end

          it "does not send notifications to the user who is muting the acting user" do
            Fabricate(:muted_user, user: user_2, muted_user: user_1)
            msg = build_cooked_msg("hey @#{user_2.username} stop muting me!", user_1)
            Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
          end

          it "does not send notifications to the user who is ignoring the acting user" do
            Fabricate(
              :ignored_user,
              user: user_2,
              ignored_user: user_1,
              expiring_at: 1.day.from_now,
            )
            msg = build_cooked_msg("hey @#{user_2.username} stop ignoring me!", user_1)
            Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
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
        let(:mention_type) { :group_chat_mention } # fixme andrei, super-hacky but this supports shared examples above
        let(:list_key) { group.name }

        include_examples "ensure only channel members are notified"

        it "calls guardian can_join_chat_channel?" do
          msg = build_cooked_msg("Hello @#{group.name} and @#{user_2.username}", user_1)
          Fabricate(:group_chat_mention, group: group, chat_message: msg)
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)

          Guardian.any_instance.expects(:can_join_chat_channel?).at_least_once
          described_class.new.execute(chat_message_id: msg.id)
        end

        it "establishes a far-left precedence among group mentions" do
          Fabricate(
            :user_chat_channel_membership,
            chat_channel: channel,
            user: user_3,
            following: true,
          )
          msg = build_cooked_msg("Hello @#{@chat_group.name} and @#{group.name}", user_1)
          left_mention = Fabricate(:group_chat_mention, group: @chat_group, chat_message: msg)
          right_mention = Fabricate(:group_chat_mention, group: group, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(left_mention.notifications.count).to be(2)
          expect(right_mention.notifications.count).to be(0)

          second_msg = build_cooked_msg("Hello @#{group.name} and @#{@chat_group.name}", user_1)
          left_mention = Fabricate(:group_chat_mention, group: group, chat_message: second_msg)
          right_mention =
            Fabricate(:group_chat_mention, group: @chat_group, chat_message: second_msg)

          described_class.new.execute(chat_message_id: second_msg.id)

          expect(left_mention.notifications.count).to be(2)
          expect(right_mention.notifications.count).to be(0)
        end

        it "skips groups with too many members" do
          SiteSetting.max_users_notified_per_group_mention = (group.user_count - 1)

          msg = build_cooked_msg("Hello @#{group.name}", user_1)
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.count).to be(0)
        end

        it "respects the 'max_mentions_per_chat_message' setting and skips notifications" do
          SiteSetting.max_mentions_per_chat_message = 1

          msg = build_cooked_msg("Hello @#{user_2.username} and @#{user_3.username}", user_1)
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.count).to be(0)
        end

        it "respects the max mentions setting and skips notifications when mixing users and groups" do
          SiteSetting.max_mentions_per_chat_message = 1

          Fabricate(
            :user_chat_channel_membership,
            chat_channel: channel,
            user: user_3,
            following: true,
          )
          msg = build_cooked_msg("Hello @#{user_2.username} and @#{group.name}", user_1)
          Fabricate(:user_chat_mention, user: user_2, chat_message: msg)
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          described_class.new.execute(chat_message_id: msg.id)

          expect(Notification.count).to be(0)
        end

        describe "users ignoring or muting the user creating the message" do
          it "does not notify users inside the group who is muting the acting user" do
            group.add(user_3)
            Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_3)
            Fabricate(:muted_user, user: user_2, muted_user: user_1)
            msg = build_cooked_msg("Hello @#{group.name}", user_1)
            Fabricate(:group_chat_mention, group: group, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
            expect(Notification.where(user: user_3).count).to be(1)
          end

          it "does not notify users inside the group who is ignoring the acting user" do
            group.add(user_3)
            Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user_3)
            Fabricate(
              :ignored_user,
              user: user_2,
              ignored_user: user_1,
              expiring_at: 1.day.from_now,
            )
            msg = build_cooked_msg("Hello @#{group.name}", user_1)
            Fabricate(:group_chat_mention, group: group, chat_message: msg)

            described_class.new.execute(chat_message_id: msg.id)

            expect(Notification.where(user: user_2).count).to be(0)
            expect(Notification.where(user: user_3).count).to be(1)
          end
        end
      end

      describe "unreachable users" do
        fab!(:user_3) { Fabricate(:user) }

        it "notify poster of users who are not allowed to use chat" do
          msg = build_cooked_msg("Hello @#{user_3.username}", user_1)
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
              expect(Notification.count).to be(0)
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
                target_usernames: [user_1.username, user_2.username],
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
            Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

            messages =
              MessageBus.track_publish("/chat/#{personal_chat_channel.id}") do
                described_class.new.execute(chat_message_id: msg.id)
                expect(Notification.count).to be(0)
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
            Fabricate(:group_chat_mention, group: group, chat_message: msg)

            messages =
              MessageBus.track_publish("/chat/#{personal_chat_channel.id}") do
                described_class.new.execute(chat_message_id: msg.id)
                expect(Notification.where(user: user_2).count).to be(1)
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
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
              expect(Notification.count).to be(0)
            end

          not_participating_msg = messages.first

          expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
          expect(not_participating_msg[:data][:text_content]).to be_nil
          expect(not_participating_msg[:data][:notice_type].to_sym).to eq(
            :mention_without_membership,
          )
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
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              Chat::Notifier.new(msg, msg.created_at).notify_new
              expect(Notification.count).to be(0)
            end

          expect(messages).to be_empty
        end

        it "cannot invite chat user without channel membership if they are muting the user who created the message" do
          Fabricate(:muted_user, user: user_3, muted_user: user_1)
          msg = build_cooked_msg("Hello @#{user_3.username}", user_1)
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              Chat::Notifier.new(msg, msg.created_at).notify_new
              expect(Notification.count).to be(0)
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
          Fabricate(:user_chat_mention, user: user_3, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
              expect(Notification.count).to be(0)
            end

          not_participating_msg = messages.first

          expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
          expect(not_participating_msg[:data][:text_content]).to be_nil
          expect(not_participating_msg[:data][:notice_type].to_sym).to eq(
            :mention_without_membership,
          )
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
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
            end

          not_participating_msg = messages.first

          expect(not_participating_msg[:data][:type].to_sym).to eq(:notice)
          expect(not_participating_msg[:data][:text_content]).to be_nil
          expect(not_participating_msg[:data][:notice_type].to_sym).to eq(
            :mention_without_membership,
          )
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
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              Chat::Notifier.new(msg, msg.created_at).notify_new
              expect(Notification.where(user: user_3).count).to be(0)
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
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              Chat::Notifier.new(msg, msg.created_at).notify_new
              expect(Notification.where(user: user_3).count).to be(0)
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
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
              expect(Notification.count).to be(0)
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
          Fabricate(:group_chat_mention, group: group, chat_message: msg)

          messages =
            MessageBus.track_publish("/chat/#{channel.id}") do
              described_class.new.execute(chat_message_id: msg.id)
              expect(Notification.count).to be(0)
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
end
