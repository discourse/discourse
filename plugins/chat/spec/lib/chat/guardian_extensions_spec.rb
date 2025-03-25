# frozen_string_literal: true

RSpec.describe Chat::GuardianExtensions do
  fab!(:chatters) { Fabricate(:group) }
  fab!(:user) { Fabricate(:user, group_ids: [chatters.id], refresh_auto_groups: true) }
  fab!(:staff) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:chat_group) { Fabricate(:group) }
  fab!(:channel) { Fabricate(:category_channel) }
  fab!(:dm_channel) { Fabricate(:direct_message_channel) }
  let(:guardian) { Guardian.new(user) }
  let(:staff_guardian) { Guardian.new(staff) }

  before { SiteSetting.chat_allowed_groups = chatters.id }

  describe "#can_chat?" do
    context "when the user is not in allowed to chat" do
      before { SiteSetting.chat_allowed_groups = "" }

      it "cannot chat" do
        expect(guardian.can_chat?).to eq(false)
      end

      context "when the user is a bot" do
        let(:guardian) { Discourse.system_user.guardian }

        it "can chat" do
          expect(guardian.can_chat?).to eq(true)
        end
      end

      context "when user is staff" do
        let(:guardian) { staff_guardian }

        it "can chat" do
          expect(guardian.can_chat?).to eq(true)
        end
      end
    end

    context "when user is anonymous" do
      let(:guardian) { Guardian.new }

      it "cannot chat" do
        expect(guardian.can_chat?).to eq(false)
      end
    end

    context "when user is a shadow account" do
      fab!(:non_chatter) { Fabricate(:user, refresh_auto_groups: true) }

      before { SiteSetting.allow_anonymous_mode = true }

      context "when allow_chat_in_anonymous_mode is true" do
        before { SiteSetting.allow_chat_in_anonymous_mode = true }

        it "allows shadow account to chat if master account can chat" do
          anonymous = AnonymousShadowCreator.get(user)
          expect(anonymous.id).to be_present
          expect(Guardian.new(anonymous).can_chat?).to eq(true)
          expect(Guardian.new(user).can_chat?).to eq(true)
        end

        it "doesn't allow shadow account to chat if master account can not chat" do
          anonymous = AnonymousShadowCreator.get(non_chatter)
          expect(anonymous.id).to be_present
          expect(Guardian.new(anonymous).can_chat?).to eq(false)
          expect(Guardian.new(non_chatter).can_chat?).to eq(false)
        end
      end

      context "when allow_chat_in_anonymous_mode is false" do
        before { SiteSetting.allow_chat_in_anonymous_mode = false }

        it "doesn't allow shadow account to chat even if master account can chat" do
          anonymous = AnonymousShadowCreator.get(user)
          expect(anonymous.id).to be_present
          expect(Guardian.new(anonymous).can_chat?).to eq(false)
          expect(Guardian.new(user).can_chat?).to eq(true)
        end

        it "doesn't allow shadow account to chat if master account can not chat" do
          anonymous = AnonymousShadowCreator.get(non_chatter)
          expect(anonymous.id).to be_present
          expect(Guardian.new(anonymous).can_chat?).to eq(false)
          expect(Guardian.new(non_chatter).can_chat?).to eq(false)
        end
      end
    end

    it "allows TL1 to chat by default and by extension higher trust levels" do
      expect(guardian.can_chat?).to eq(true)
      user.change_trust_level!(TrustLevel[3])
      expect(guardian.can_chat?).to eq(true)
    end

    it "allows user in specific group to chat" do
      SiteSetting.chat_allowed_groups = chat_group.id
      expect(guardian.can_chat?).to eq(false)
      chat_group.add(user)
      user.reload
      expect(guardian.can_chat?).to eq(true)
    end
  end

  describe "chat channel" do
    it "only staff can create channels" do
      expect(guardian.can_create_chat_channel?).to eq(false)
      expect(staff_guardian.can_create_chat_channel?).to eq(true)
    end

    context "when category channel" do
      it "allows staff to edit chat channels" do
        expect(guardian.can_edit_chat_channel?(channel)).to eq(false)
        expect(staff_guardian.can_edit_chat_channel?(channel)).to eq(true)
      end
    end

    context "when direct message channel" do
      context "when member of channel" do
        context "when group" do
          before do
            dm_channel.chatable.update!(group: true)
            add_users_to_channel(user, dm_channel)
          end

          it "allows to edit the channel" do
            expect(user.guardian.can_edit_chat_channel?(dm_channel)).to eq(true)
          end
        end

        context "when not group" do
          before { dm_channel.add(user) }

          it "allows to edit the channel" do
            Chat::DirectMessageUser.create(user: user, direct_message: dm_channel.chatable)
            expect(user.guardian.can_edit_chat_channel?(dm_channel)).to eq(true)
          end
        end
      end

      context "when not member of channel" do
        it "doesn’t allow to edit the channel" do
          expect(user.guardian.can_edit_chat_channel?(dm_channel)).to eq(false)
        end
      end
    end

    it "only staff can close chat channels" do
      channel.update(status: :open)
      expect(guardian.can_change_channel_status?(channel, :closed)).to eq(false)
      expect(staff_guardian.can_change_channel_status?(channel, :closed)).to eq(true)
    end

    it "only staff can open chat channels" do
      channel.update(status: :closed)
      expect(guardian.can_change_channel_status?(channel, :open)).to eq(false)
      expect(staff_guardian.can_change_channel_status?(channel, :open)).to eq(true)
    end

    it "only staff can archive chat channels" do
      channel.update(status: :read_only)
      expect(guardian.can_change_channel_status?(channel, :archived)).to eq(false)
      expect(staff_guardian.can_change_channel_status?(channel, :archived)).to eq(true)
    end

    it "only staff can mark chat channels read_only" do
      channel.update(status: :open)
      expect(guardian.can_change_channel_status?(channel, :read_only)).to eq(false)
      expect(staff_guardian.can_change_channel_status?(channel, :read_only)).to eq(true)
    end

    describe "#can_join_chat_channel?" do
      context "for direct message channels" do
        fab!(:chatable) { Fabricate(:direct_message) }
        fab!(:channel) { Fabricate(:direct_message_channel, chatable: chatable) }

        it "returns false if the user is not part of the direct message" do
          expect(guardian.can_join_chat_channel?(channel)).to eq(false)
        end

        it "returns true if the user is part of the direct message" do
          Chat::DirectMessageUser.create!(user: user, direct_message: chatable)
          expect(guardian.can_join_chat_channel?(channel)).to eq(true)
        end
      end

      context "for category channel" do
        fab!(:group)
        fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }

        it "returns true if the user can join the category" do
          category =
            Fabricate(
              :private_category,
              group: group,
              permission_type: CategoryGroup.permission_types[:readonly],
            )
          channel.update(chatable: category)
          guardian = Guardian.new(user)
          expect(guardian.can_join_chat_channel?(channel)).to eq(false)

          category =
            Fabricate(
              :private_category,
              group: group,
              permission_type: CategoryGroup.permission_types[:create_post],
            )
          channel.update(chatable: category)
          guardian = Guardian.new(user)
          expect(guardian.can_join_chat_channel?(channel)).to eq(true)

          category =
            Fabricate(
              :private_category,
              group: group,
              permission_type: CategoryGroup.permission_types[:full],
            )
          channel.update(chatable: category)
          guardian = Guardian.new(user)
          expect(guardian.can_join_chat_channel?(channel)).to eq(true)
        end
      end
    end

    describe "#can_post_in_chatable?" do
      alias_matcher :be_able_to_post_in_chatable, :be_can_post_in_chatable

      context "when channel is a category channel" do
        context "when post_allowed_category_ids given" do
          context "when no chatable given" do
            it "returns false" do
              expect(guardian).not_to be_able_to_post_in_chatable(
                nil,
                post_allowed_category_ids: [channel.chatable.id],
              )
            end
          end

          context "when user is anonymous" do
            it "returns false" do
              expect(Guardian.new).not_to be_able_to_post_in_chatable(
                channel.chatable,
                post_allowed_category_ids: [channel.chatable.id],
              )
            end
          end

          context "when user is admin" do
            it "returns true" do
              guardian = Fabricate(:admin).guardian
              expect(guardian).to be_able_to_post_in_chatable(
                channel.chatable,
                post_allowed_category_ids: [channel.chatable.id],
              )
            end
          end

          context "when chatable id is part of allowed ids" do
            it "returns true" do
              expect(guardian).to be_able_to_post_in_chatable(
                channel.chatable,
                post_allowed_category_ids: [channel.chatable.id],
              )
            end
          end

          context "when chatable id is not part of allowed ids" do
            it "returns false" do
              expect(guardian).not_to be_able_to_post_in_chatable(
                channel.chatable,
                post_allowed_category_ids: [-1],
              )
            end
          end
        end

        context "when no post_allowed_category_ids given" do
          context "when no chatable given" do
            it "returns false" do
              expect(guardian).not_to be_able_to_post_in_chatable(nil)
            end
          end

          context "when user is anonymous" do
            it "returns false" do
              expect(Guardian.new).not_to be_able_to_post_in_chatable(channel.chatable)
            end
          end

          context "when user is admin" do
            it "returns true" do
              guardian = Fabricate(:admin).guardian
              expect(guardian).to be_able_to_post_in_chatable(channel.chatable)
            end
          end

          context "when chatable id is part of allowed ids" do
            it "returns true" do
              expect(guardian).to be_able_to_post_in_chatable(channel.chatable)
            end
          end

          context "when user can't post in chatable" do
            fab!(:group)
            fab!(:channel) { Fabricate(:private_category_channel, group: group) }

            before do
              channel.chatable.category_groups.first.update!(
                permission_type: CategoryGroup.permission_types[:readonly],
              )
              group.add(user)
              channel.add(user)
            end

            it "returns false" do
              expect(guardian).not_to be_able_to_post_in_chatable(channel.chatable)
            end
          end
        end
      end

      context "when channel is a direct message channel" do
        let(:channel) { Fabricate(:direct_message_channel) }

        it "returns true" do
          expect(guardian).to be_able_to_post_in_chatable(channel.chatable)
        end
      end
    end

    describe "#can_flag_in_chat_channel?" do
      alias_matcher :be_able_to_flag_in_chat_channel, :be_can_flag_in_chat_channel

      context "when channel is a direct message channel" do
        let(:channel) { Fabricate(:direct_message_channel) }

        it "returns false" do
          expect(guardian).not_to be_able_to_flag_in_chat_channel(channel)
        end
      end

      context "when channel is a category channel" do
        it "returns true" do
          expect(guardian).to be_able_to_flag_in_chat_channel(channel)
        end
      end

      context "with a private channel" do
        let(:private_group) { Fabricate(:group) }
        let(:private_category) { Fabricate(:private_category, group: private_group) }
        let(:private_channel) { Fabricate(:category_channel, chatable: private_category) }

        context "when the user can't see the channel" do
          it "returns false" do
            expect(guardian).not_to be_able_to_flag_in_chat_channel(private_channel)
          end
        end

        context "when the user can see the channel" do
          before { private_group.add(user) }

          it "returns true" do
            expect(guardian).to be_able_to_flag_in_chat_channel(private_channel)
          end
        end
      end
    end

    describe "#can_flag_chat_message?" do
      let!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      before { SiteSetting.chat_message_flag_allowed_groups = "" }

      context "when user isn't staff" do
        it "returns false" do
          expect(guardian.can_flag_chat_message?(message)).to eq(false)
        end
      end

      context "when user is staff" do
        it "returns true" do
          expect(staff_guardian.can_flag_chat_message?(message)).to eq(true)
        end
      end
    end

    describe "#can_moderate_chat?" do
      context "for category channel" do
        fab!(:category) { Fabricate(:category, read_restricted: true) }

        before { channel.update(chatable: category) }

        it "returns true for staff and false for regular users" do
          expect(staff_guardian.can_moderate_chat?(channel.chatable)).to eq(true)
          expect(guardian.can_moderate_chat?(channel.chatable)).to eq(false)
        end

        context "when enable_category_group_moderation is true" do
          before { SiteSetting.enable_category_group_moderation = true }

          it "returns true if the regular user is part of the reviewable groups for the category" do
            moderator = Fabricate(:user)
            mods = Fabricate(:group)
            mods.add(moderator)
            Fabricate(:category_moderation_group, category:, group: mods)
            expect(Guardian.new(Fabricate(:admin)).can_moderate_chat?(channel.chatable)).to eq(true)
            expect(Guardian.new(moderator).can_moderate_chat?(channel.chatable)).to eq(true)
          end
        end
      end

      context "for DM channel" do
        fab!(:dm_channel) { Chat::DirectMessage.create! }

        before { channel.update(chatable_type: "DirectMessageType", chatable: dm_channel) }

        it "returns true for staff and false for regular users" do
          expect(staff_guardian.can_moderate_chat?(channel.chatable)).to eq(true)
          expect(guardian.can_moderate_chat?(channel.chatable)).to eq(false)
        end
      end
    end

    describe "#can_restore_chat?" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user) }
      fab!(:chatable) { Fabricate(:category) }

      context "when channel is closed" do
        before { channel.update!(status: :closed) }

        it "disallows a owner to restore" do
          expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
        end

        it "allows a staff to restore" do
          expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
        end
      end

      context "when chatable is a direct message" do
        fab!(:chatable) { Chat::DirectMessage.create! }

        it "allows owner to restore when deleted by owner" do
          message.trash!(guardian.user)
          expect(guardian.can_restore_chat?(message, chatable)).to eq(true)
        end

        it "disallow owner to restore when deleted by staff" do
          message.trash!(staff_guardian.user)
          expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
        end

        it "allows staff to restore" do
          expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
        end
      end

      context "when user is not owner of the message" do
        fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: Fabricate(:user)) }

        context "when chatable is a category" do
          context "when category is not restricted" do
            it "allows staff to restore" do
              expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
            end

            it "disallows any user to restore" do
              expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
            end
          end

          context "when category is restricted" do
            fab!(:chatable) { Fabricate(:category, read_restricted: true) }

            it "allows staff to restore" do
              expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
            end

            it "disallows any user to restore" do
              expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
            end

            context "when group moderation is enabled" do
              before { SiteSetting.enable_category_group_moderation = true }

              it "allows a group moderator to restore" do
                moderator = Fabricate(:user)
                mods = Fabricate(:group)
                mods.add(moderator)
                Fabricate(:category_moderation_group, category: chatable, group: mods)
                expect(Guardian.new(moderator).can_restore_chat?(message, chatable)).to eq(true)
              end
            end
          end

          context "when chatable is a direct message" do
            fab!(:chatable) { Chat::DirectMessage.create! }

            it "allows staff to restore" do
              expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
            end

            it "disallows any user to restore" do
              expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
            end
          end
        end
      end

      context "when user is owner of the message" do
        context "when chatable is a category" do
          it "allows to restore if owner can see category" do
            expect(guardian.can_restore_chat?(message, chatable)).to eq(true)
          end

          context "when category is restricted" do
            fab!(:chatable) { Fabricate(:category, read_restricted: true) }

            it "disallows to restore if owner can't see category" do
              expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
            end

            it "allows staff to restore" do
              expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
            end
          end
        end

        context "when chatable is a direct message" do
          fab!(:chatable) { Chat::DirectMessage.create! }

          it "allows staff to restore" do
            expect(staff_guardian.can_restore_chat?(message, chatable)).to eq(true)
          end

          it "allows owner to restore when deleted by owner" do
            message.trash!(guardian.user)
            expect(guardian.can_restore_chat?(message, chatable)).to eq(true)
          end

          it "disallow owner to restore when deleted by staff" do
            message.trash!(staff_guardian.user)
            expect(guardian.can_restore_chat?(message, chatable)).to eq(false)
          end
        end
      end
    end

    describe "#can_edit_chat" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      context "when user is staff" do
        it "returns true" do
          expect(staff_guardian.can_edit_chat?(message)).to eq(true)
        end
      end

      context "when user is not staff" do
        it "returns false" do
          expect(guardian.can_edit_chat?(message)).to eq(false)
        end
      end

      context "when user is owner of the message" do
        fab!(:message) { Fabricate(:chat_message, chat_channel: channel, user: user) }

        it "returns true" do
          expect(guardian.can_edit_chat?(message)).to eq(true)
        end
      end
    end

    describe "#can_delete_category?" do
      alias_matcher :be_able_to_delete_category, :be_can_delete_category

      let(:category) { channel.chatable }

      context "when user is staff" do
        context "when category has no channel" do
          before do
            category.category_channel.destroy
            category.reload
          end

          it "allows to delete the category" do
            expect(staff_guardian).to be_able_to_delete_category(category)
          end
        end

        context "when category has a channel" do
          context "when channel has no messages" do
            it "allows to delete the category" do
              expect(staff_guardian).to be_able_to_delete_category(category)
            end
          end

          context "when channel has messages" do
            let!(:message) { Fabricate(:chat_message, chat_channel: channel) }

            it "does not allow to delete the category" do
              expect(staff_guardian).not_to be_able_to_delete_category(category)
            end
          end
        end
      end

      context "when user is not staff" do
        context "when category has no channel" do
          before do
            category.category_channel.destroy
            category.reload
          end

          it "does not allow to delete the category" do
            expect(guardian).not_to be_able_to_delete_category(category)
          end
        end

        context "when category has a channel" do
          context "when channel has no messages" do
            it "does not allow to delete the category" do
              expect(guardian).not_to be_able_to_delete_category(category)
            end
          end

          context "when channel has messages" do
            let!(:message) { Fabricate(:chat_message, chat_channel: channel) }

            it "does not allow to delete the category" do
              expect(guardian).not_to be_able_to_delete_category(category)
            end
          end
        end
      end
    end
  end

  describe "#can_create_channel_message?" do
    context "when user is staff" do
      it "returns true if the channel is open" do
        channel.update!(status: :open)
        expect(staff_guardian.can_create_channel_message?(channel)).to eq(true)
      end

      it "returns true if the channel is closed" do
        channel.update!(status: :closed)
        expect(staff_guardian.can_create_channel_message?(channel)).to eq(true)
      end

      it "returns false if the channel is archived" do
        channel.update!(status: :archived)
        expect(staff_guardian.can_create_channel_message?(channel)).to eq(false)
      end

      context "for direct message channels" do
        it "returns true if the channel is open" do
          dm_channel.update!(status: :open)
          expect(staff_guardian.can_create_channel_message?(dm_channel)).to eq(true)
        end
      end
    end

    context "when user is not staff" do
      it "returns true if the channel is open" do
        channel.update!(status: :open)
        expect(guardian.can_create_channel_message?(channel)).to eq(true)
      end

      it "returns false if the channel is closed" do
        channel.update!(status: :closed)
        expect(guardian.can_create_channel_message?(channel)).to eq(false)
      end

      it "returns false if the channel is archived" do
        channel.update!(status: :archived)
        expect(guardian.can_create_channel_message?(channel)).to eq(false)
      end
    end
  end

  describe "#can_send_direct_message?" do
    fab!(:other_user) { Fabricate(:user) }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, other_user]) }
    alias_matcher :be_able_to_send_direct_message, :be_can_send_direct_message

    context "when sender is chatting to self" do
      let(:dm_channel_solo) { Fabricate(:direct_message_channel, users: [user]) }

      it "returns true" do
        expect(guardian).to be_able_to_send_direct_message(dm_channel_solo)
      end
    end

    context "when sender is not in chat enabled groups" do
      before { SiteSetting.chat_allowed_groups = "" }

      it "returns false" do
        expect(guardian).not_to be_able_to_send_direct_message(dm_channel)
      end
    end

    context "when sender is suspended" do
      before do
        UserSuspender.new(
          user,
          suspended_till: 1.day.from_now,
          by_user: Discourse.system_user,
          reason: "spam",
        ).suspend
      end

      it "returns false" do
        expect(guardian).not_to be_able_to_send_direct_message(dm_channel)
      end
    end

    context "when sender is a bot" do
      before { user.id = -1 }

      it "returns true" do
        expect(guardian).to be_able_to_send_direct_message(dm_channel)
      end
    end
  end

  describe "#allowing_direct_messages?" do
    context "when user has disabled private messages" do
      before { user.user_option.update!(allow_private_messages: false) }

      it "returns false" do
        expect(guardian.allowing_direct_messages?).to eq(false)
      end
    end

    context "when user has enabled private messages" do
      it "returns true" do
        expect(guardian.allowing_direct_messages?).to eq(true)
      end
    end
  end

  describe "#recipient_can_chat?" do
    fab!(:other_user) { Fabricate(:user, groups: [chatters]) }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, other_user]) }
    alias_matcher :be_able_to_chat, :be_recipient_can_chat

    context "when target user is not in chat enabled groups" do
      before { SiteSetting.chat_allowed_groups = "" }

      it "returns false" do
        expect(guardian).not_to be_able_to_chat(other_user)
      end
    end

    context "when target user is not in direct message enabled groups" do
      before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:admins] }

      it "returns true" do
        expect(guardian).to be_able_to_chat(other_user)
      end
    end

    context "when target user has disabled chat" do
      before { other_user.user_option.update!(chat_enabled: false) }

      it "returns false" do
        expect(guardian).not_to be_able_to_chat(other_user)
      end
    end
  end

  describe "#recipient_not_muted?" do
    fab!(:other_user) { Fabricate(:user) }

    context "when target user is not muted" do
      it "returns true" do
        expect(guardian.recipient_not_muted?(other_user)).to eq(true)
      end
    end

    context "when target user is muted" do
      before { MutedUser.create!(user: user, muted_user: other_user) }

      it "returns false" do
        expect(guardian.recipient_not_muted?(other_user)).to eq(false)
      end
    end
  end

  describe "#recipient_not_ignored?" do
    fab!(:other_user) { Fabricate(:user) }

    context "when target user is not ignored" do
      it "returns true" do
        expect(guardian.recipient_not_ignored?(other_user)).to eq(true)
      end
    end

    context "when target user is ignored" do
      before do
        IgnoredUser.create!(user: user, ignored_user: other_user, expiring_at: 1.day.from_now)
      end

      it "returns false" do
        expect(guardian.recipient_not_ignored?(other_user)).to eq(false)
      end
    end
  end

  describe "#recipient_allows_direct_messages?" do
    fab!(:other_user) { Fabricate(:user) }
    alias_matcher :be_able_to_receive_direct_message, :be_recipient_allows_direct_messages

    context "when target user has disabled private messages" do
      before { other_user.user_option.update(allow_private_messages: false) }

      it "returns false" do
        expect(guardian).not_to be_able_to_receive_direct_message(other_user)
      end
    end

    context "when target user is suspended" do
      before do
        UserSuspender.new(
          other_user,
          suspended_till: 1.day.from_now,
          by_user: Discourse.system_user,
          reason: "spam",
        ).suspend
      end

      it "returns false" do
        expect(guardian).not_to be_able_to_receive_direct_message(other_user)
      end
    end

    context "when sender is ignored by target user" do
      before do
        IgnoredUser.create!(user: other_user, ignored_user: user, expiring_at: 1.day.from_now)
      end

      it "returns false" do
        expect(guardian).not_to be_able_to_receive_direct_message(other_user)
      end
    end

    context "when sender is muted by target user" do
      before { MutedUser.create!(user: other_user, muted_user: user) }

      it "returns false" do
        expect(guardian).not_to be_able_to_receive_direct_message(other_user)
      end
    end

    context "when staff is muted by target user" do
      before { MutedUser.create!(user: other_user, muted_user: staff) }

      it "returns true" do
        expect(staff_guardian).to be_able_to_receive_direct_message(other_user)
      end
    end

    context "when staff is ignored by target user" do
      before do
        IgnoredUser.create!(user: other_user, ignored_user: staff, expiring_at: 1.day.from_now)
      end

      it "returns true" do
        expect(staff_guardian).to be_able_to_receive_direct_message(other_user)
      end
    end
  end
end
