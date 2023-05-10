# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::ChatController do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:category) { Fabricate(:category) }
  fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }
  fab!(:dm_chat_channel) { Fabricate(:direct_message_channel, users: [user, other_user, admin]) }
  fab!(:tag) { Fabricate(:tag) }

  MESSAGE_COUNT = 70
  MESSAGE_COUNT.times do |n|
    fab!("message_#{n}") do
      Fabricate(
        :chat_message,
        chat_channel: chat_channel,
        user: other_user,
        message: "message #{n}",
      )
    end
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def flag_message(message, flagger, flag_type: ReviewableScore.types[:off_topic])
    Chat::ReviewQueue.new.flag_message(message, Guardian.new(flagger), flag_type)[:reviewable]
  end

  describe "#messages" do
    let(:page_size) { 30 }

    before do
      sign_in(user)
      Group.refresh_automatic_groups!
    end

    it "errors for user when they are not allowed to chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.status).to eq(403)
    end

    it "errors when page size is over 50" do
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: 51 }
      expect(response.status).to eq(400)
    end

    it "errors when page size is nil" do
      get "/chat/#{chat_channel.id}/messages.json"
      expect(response.status).to eq(400)
    end

    it "returns the latest messages in created_at, id order" do
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      messages = response.parsed_body["chat_messages"]
      expect(messages.count).to eq(page_size)
      expect(messages.first["created_at"].to_time).to be < messages.last["created_at"].to_time
    end

    it "returns `can_flag=true` for public channels" do
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["can_flag"]).to be true
    end

    it "returns `can_flag=true` for DM channels" do
      get "/chat/#{dm_chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["can_flag"]).to be true
    end

    it "returns `can_moderate=true` based on whether the user can moderate the chatable" do
      1.upto(4) do |n|
        user.update!(trust_level: n)
        get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
        expect(response.parsed_body["meta"]["can_moderate"]).to be false
      end

      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["can_moderate"]).to be false

      user.update!(admin: true)
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["can_moderate"]).to be true
      user.update!(admin: false)

      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      group.add(user)
      category.update!(reviewable_by_group: group)
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["can_moderate"]).to be true
    end

    it "serializes `user_flag_status` for user who has a pending flag" do
      chat_message = chat_channel.chat_messages.last
      reviewable = flag_message(chat_message, user)
      score = reviewable.reviewable_scores.last

      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }

      expect(response.parsed_body["chat_messages"].last["user_flag_status"]).to eq(
        score.status_for_database,
      )
    end

    it "doesn't serialize `reviewable_ids` for non-staff" do
      reviewable = flag_message(chat_channel.chat_messages.last, admin)

      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }

      expect(response.parsed_body["chat_messages"].last["reviewable_id"]).to be_nil
    end

    it "serializes `reviewable_ids` correctly for staff" do
      sign_in(admin)
      reviewable = flag_message(chat_channel.chat_messages.last, admin)

      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["chat_messages"].last["reviewable_id"]).to eq(reviewable.id)
    end

    it "correctly marks reactions as 'reacted' for the current_user" do
      heart_emoji = ":heart:"
      smile_emoji = ":smile"
      last_message = chat_channel.chat_messages.last
      last_message.reactions.create(user: user, emoji: heart_emoji)
      last_message.reactions.create(user: admin, emoji: smile_emoji)

      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }

      reactions = response.parsed_body["chat_messages"].last["reactions"]
      heart_reaction = reactions.find { |r| r["emoji"] == heart_emoji }
      expect(heart_reaction["reacted"]).to be true
      smile_reaction = reactions.find { |r| r["emoji"] == smile_emoji }
      expect(smile_reaction["reacted"]).to be false
    end

    it "sends the last message bus id for the channel" do
      get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }
      expect(response.parsed_body["meta"]["channel_message_bus_last_id"]).not_to eq(nil)
    end

    describe "scrolling to the past" do
      it "returns the correct messages in created_at, id order" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_40.id,
              direction: described_class::PAST,
              page_size: page_size,
            }
        messages = response.parsed_body["chat_messages"]
        expect(messages.count).to eq(page_size)
        expect(messages.first["created_at"].to_time).to eq_time(message_10.created_at)
        expect(messages.last["created_at"].to_time).to eq_time(message_39.created_at)
      end

      it "returns 'can_load...' properly when there are more past messages" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_40.id,
              direction: described_class::PAST,
              page_size: page_size,
            }
        expect(response.parsed_body["meta"]["can_load_more_past"]).to be true
        expect(response.parsed_body["meta"]["can_load_more_future"]).to be_nil
      end

      it "returns 'can_load...' properly when there are no past messages" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_3.id,
              direction: described_class::PAST,
              page_size: page_size,
            }
        expect(response.parsed_body["meta"]["can_load_more_past"]).to be false
        expect(response.parsed_body["meta"]["can_load_more_future"]).to be_nil
      end
    end

    describe "scrolling to the future" do
      it "returns the correct messages in created_at, id order when there are many after" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_10.id,
              direction: described_class::FUTURE,
              page_size: page_size,
            }
        messages = response.parsed_body["chat_messages"]
        expect(messages.count).to eq(page_size)
        expect(messages.first["created_at"].to_time).to eq_time(message_11.created_at)
        expect(messages.last["created_at"].to_time).to eq_time(message_40.created_at)
      end

      it "return 'can_load..' properly when there are future messages" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_10.id,
              direction: described_class::FUTURE,
              page_size: page_size,
            }
        expect(response.parsed_body["meta"]["can_load_more_past"]).to be_nil
        expect(response.parsed_body["meta"]["can_load_more_future"]).to be true
      end

      it "returns 'can_load..' properly when there are no future messages" do
        get "/chat/#{chat_channel.id}/messages.json",
            params: {
              message_id: message_60.id,
              direction: described_class::FUTURE,
              page_size: page_size,
            }
        expect(response.parsed_body["meta"]["can_load_more_past"]).to be_nil
        expect(response.parsed_body["meta"]["can_load_more_future"]).to be false
      end
    end

    describe "without direction (latest messages)" do
      it "signals there are no future messages" do
        get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }

        expect(response.parsed_body["meta"]["can_load_more_future"]).to eq(false)
      end

      it "signals there are more messages in the past" do
        get "/chat/#{chat_channel.id}/messages.json", params: { page_size: page_size }

        expect(response.parsed_body["meta"]["can_load_more_past"]).to eq(true)
      end

      it "signals there are no more messages" do
        new_channel = Fabricate(:category_channel)
        Fabricate(:chat_message, chat_channel: new_channel, user: other_user, message: "message")
        chat_messages_qty = 1

        get "/chat/#{new_channel.id}/messages.json", params: { page_size: chat_messages_qty + 1 }

        expect(response.parsed_body["meta"]["can_load_more_past"]).to eq(false)
      end
    end
  end

  describe "#enable_chat" do
    context "with category as chatable" do
      let!(:category) { Fabricate(:category) }
      let(:channel) { Fabricate(:category_channel, chatable: category) }

      it "ensures created channel can be seen" do
        Guardian.any_instance.expects(:can_join_chat_channel?).with(channel)

        sign_in(admin)
        post "/chat/enable.json", params: { chatable_type: "Category", chatable_id: category.id }
      end

      # TODO: rewrite specs to ensure no exception is raised
      it "ensures existing channel can be seen" do
        Guardian.any_instance.expects(:can_join_chat_channel?)

        sign_in(admin)
        post "/chat/enable.json", params: { chatable_type: "Category", chatable_id: category.id }
      end
    end
  end

  describe "#disable_chat" do
    context "with category as chatable" do
      it "ensures category can be seen" do
        category = Fabricate(:category)
        channel = Fabricate(:category_channel, chatable: category)
        message = Fabricate(:chat_message, chat_channel: channel)

        Guardian.any_instance.expects(:can_join_chat_channel?).with(channel)

        sign_in(admin)
        post "/chat/disable.json", params: { chatable_type: "Category", chatable_id: category.id }
      end
    end
  end

  describe "#create_message" do
    let(:message) { "This is a message" }

    describe "for category" do
      fab!(:chat_channel) { Fabricate(:category_channel, chatable: category) }

      context "when current user is silenced" do
        before do
          Chat::UserChatChannelMembership.create(
            user: user,
            chat_channel: chat_channel,
            following: true,
          )
          sign_in(user)
          UserSilencer.new(user).silence
        end

        it "raises invalid acces" do
          post "/chat/#{chat_channel.id}.json", params: { message: message }
          expect(response.status).to eq(403)
        end
      end

      it "errors for regular user when chat is staff-only" do
        sign_in(user)
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]

        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)
      end

      it "errors when the user isn't following the channel" do
        sign_in(user)

        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)
      end

      it "errors when the user is not staff and the channel is not open" do
        Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user)
        sign_in(user)

        chat_channel.update(status: :closed)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.channel_new_message_disallowed.closed"),
        )
      end

      it "errors when the user is staff and the channel is not open or closed" do
        Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: admin)
        sign_in(admin)

        chat_channel.update(status: :closed)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)

        chat_channel.update(status: :read_only)
        post "/chat/#{chat_channel.id}.json", params: { message: message }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("chat.errors.channel_new_message_disallowed.read_only"),
        )
      end

      context "when the regular user is following the channel" do
        fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel) }
        fab!(:membership) do
          Chat::UserChatChannelMembership.create(
            user: user,
            chat_channel: chat_channel,
            following: true,
            last_read_message_id: message_1.id,
          )
        end

        it "sends a message for regular user when staff-only is disabled and they are following channel" do
          sign_in(user)

          expect { post "/chat/#{chat_channel.id}.json", params: { message: message } }.to change {
            Chat::Message.count
          }.by(1)
          expect(response.status).to eq(200)
          expect(Chat::Message.last.message).to eq(message)
        end

        it "updates the last_read_message_id for the user who sent the message" do
          sign_in(user)
          post "/chat/#{chat_channel.id}.json", params: { message: message }
          expect(response.status).to eq(200)
          expect(membership.reload.last_read_message_id).to eq(Chat::Message.last.id)
        end

        it "publishes user tracking state using the new chat message as the last_read_message_id" do
          sign_in(user)
          messages =
            MessageBus.track_publish(
              Chat::Publisher.user_tracking_state_message_bus_channel(user.id),
            ) { post "/chat/#{chat_channel.id}.json", params: { message: message } }
          expect(response.status).to eq(200)
          expect(messages.first.data["last_read_message_id"]).to eq(Chat::Message.last.id)
        end

        context "when sending a message in a staged thread" do
          it "creates the thread and publishes with the staged id" do
            sign_in(user)
            chat_channel.update!(threading_enabled: true)

            messages =
              MessageBus.track_publish do
                post "/chat/#{chat_channel.id}.json",
                     params: {
                       message: message,
                       in_reply_to_id: message_1.id,
                       staged_thread_id: "stagedthreadid",
                     }
              end

            expect(response.status).to eq(200)

            thread_event = messages.find { |m| m.data["type"] == "thread_created" }
            expect(thread_event.data["staged_thread_id"]).to eq("stagedthreadid")
            expect(Chat::Thread.find(thread_event.data["thread_id"])).to be_persisted

            sent_event = messages.find { |m| m.data["type"] == "sent" }
            expect(sent_event.data["staged_thread_id"]).to eq("stagedthreadid")
          end
        end

        context "when sending a message in a thread" do
          fab!(:thread) do
            Fabricate(:chat_thread, channel: chat_channel, original_message: message_1)
          end

          it "does not update the last_read_message_id for the user who sent the message" do
            sign_in(user)
            post "/chat/#{chat_channel.id}.json", params: { message: message, thread_id: thread.id }
            expect(response.status).to eq(200)
            expect(membership.reload.last_read_message_id).to eq(message_1.id)
          end

          it "publishes user tracking state using the old membership last_read_message_id" do
            sign_in(user)
            messages =
              MessageBus.track_publish(
                Chat::Publisher.user_tracking_state_message_bus_channel(user.id),
              ) do
                post "/chat/#{chat_channel.id}.json",
                     params: {
                       message: message,
                       thread_id: thread.id,
                     }
              end
            expect(response.status).to eq(200)
            expect(messages.first.data["last_read_message_id"]).to eq(message_1.id)
          end
        end
      end
    end

    describe "for direct message" do
      fab!(:user1) { Fabricate(:user) }
      fab!(:user2) { Fabricate(:user) }
      fab!(:chatable) { Fabricate(:direct_message, users: [user1, user2]) }
      fab!(:direct_message_channel) { Fabricate(:direct_message_channel, chatable: chatable) }

      it "forces users to follow the channel" do
        direct_message_channel.remove(user2)

        Chat::Publisher.expects(:publish_new_channel).once

        sign_in(user1)

        post "/chat/#{direct_message_channel.id}.json", params: { message: message }

        expect(Chat::UserChatChannelMembership.find_by(user_id: user2.id).following).to be true
      end

      it "errors when the user is not part of the direct message channel" do
        Chat::DirectMessageUser.find_by(user: user1, direct_message: chatable).destroy!
        sign_in(user1)
        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
        expect(response.status).to eq(403)

        Chat::UserChatChannelMembership.find_by(user_id: user2.id).update!(following: true)
        sign_in(user2)
        post "/chat/#{direct_message_channel.id}.json", params: { message: message }
        expect(response.status).to eq(200)
      end

      context "when current user is silenced" do
        before do
          sign_in(user1)
          UserSilencer.new(user1).silence
        end

        it "raises invalid acces" do
          post "/chat/#{direct_message_channel.id}.json", params: { message: message }
          expect(response.status).to eq(403)
        end
      end

      context "if any of the direct message users is ignoring the acting user" do
        before do
          IgnoredUser.create!(user: user2, ignored_user: user1, expiring_at: 1.day.from_now)
        end

        it "does not force them to follow the channel or send a publish_new_channel message" do
          direct_message_channel.remove(user2)

          Chat::Publisher.expects(:publish_new_channel).never

          sign_in(user1)
          post "/chat/#{direct_message_channel.id}.json", params: { message: message }

          expect(Chat::UserChatChannelMembership.find_by(user_id: user2.id).following).to be false
        end
      end
    end
  end

  describe "#rebake" do
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }

    context "as staff" do
      it "rebakes the post" do
        sign_in(Fabricate(:admin))

        expect_enqueued_with(
          job: Jobs::Chat::ProcessMessage,
          args: {
            chat_message_id: chat_message.id,
          },
        ) do
          put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"

          expect(response.status).to eq(200)
        end
      end

      it "does not interfere with core's guardian can_rebake? for posts" do
        sign_in(Fabricate(:admin))
        put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
        expect(response.status).to eq(200)
        post = Fabricate(:post)
        put "/posts/#{post.id}/rebake.json"
        expect(response.status).to eq(200)
      end

      it "does not rebake the post when channel is read_only" do
        chat_message.chat_channel.update!(status: :read_only)
        sign_in(Fabricate(:admin))

        put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
        expect(response.status).to eq(403)
      end

      context "when cooked has changed" do
        it "marks the message as dirty" do
          sign_in(Fabricate(:admin))
          chat_message.update!(message: "new content")

          expect_enqueued_with(
            job: Jobs::Chat::ProcessMessage,
            args: {
              chat_message_id: chat_message.id,
              is_dirty: true,
            },
          ) do
            put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"

            expect(response.status).to eq(200)
          end
        end
      end
    end

    context "when not staff" do
      it "forbids non staff to rebake" do
        sign_in(Fabricate(:user))
        put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
        expect(response.status).to eq(403)
      end

      context "as TL3 user" do
        it "forbids less then TL4 user tries to rebake" do
          sign_in(Fabricate(:user, trust_level: TrustLevel[3]))
          put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
          expect(response.status).to eq(403)
        end
      end

      context "as TL4 user" do
        it "allows TL4 users to rebake" do
          sign_in(Fabricate(:user, trust_level: TrustLevel[4]))
          put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
          expect(response.status).to eq(200)
        end

        it "does not rebake the post when channel is read_only" do
          chat_message.chat_channel.update!(status: :read_only)
          sign_in(Fabricate(:user, trust_level: TrustLevel[4]))

          put "/chat/#{chat_channel.id}/#{chat_message.id}/rebake.json"
          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "#edit_message" do
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }

    context "when current user is silenced" do
      before do
        UserSilencer.new(user).silence
        sign_in(user)
      end

      it "raises an invalid request" do
        put "/chat/#{chat_channel.id}/edit/#{chat_message.id}.json", params: { new_message: "Hi" }
        expect(response.status).to eq(422)
      end
    end

    it "errors when a user tries to edit another user's message" do
      sign_in(Fabricate(:user))

      put "/chat/#{chat_channel.id}/edit/#{chat_message.id}.json", params: { new_message: "edit!" }
      expect(response.status).to eq(422)
    end

    it "errors when staff tries to edit another user's message" do
      sign_in(admin)
      new_message = "Vrroooom cars go fast"

      put "/chat/#{chat_channel.id}/edit/#{chat_message.id}.json",
          params: {
            new_message: new_message,
          }
      expect(response.status).to eq(422)
    end

    it "allows a user to edit their own messages" do
      sign_in(user)
      new_message = "Wow markvanlan must be a good programmer"

      put "/chat/#{chat_channel.id}/edit/#{chat_message.id}.json",
          params: {
            new_message: new_message,
          }
      expect(response.status).to eq(200)
      expect(chat_message.reload.message).to eq(new_message)
    end
  end

  describe "react" do
    fab!(:chat_channel) { Fabricate(:category_channel) }
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: user) }
    fab!(:user_membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user)
    end

    fab!(:private_chat_channel) do
      Fabricate(:category_channel, chatable: Fabricate(:private_category, group: Fabricate(:group)))
    end
    fab!(:private_chat_message) do
      Fabricate(:chat_message, chat_channel: private_chat_channel, user: admin)
    end
    fab!(:private_user_membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: private_chat_channel, user: user)
    end

    fab!(:chat_channel_no_memberships) { Fabricate(:category_channel) }
    fab!(:chat_message_no_memberships) do
      Fabricate(:chat_message, chat_channel: chat_channel_no_memberships, user: user)
    end

    it "errors with invalid emoji" do
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: 12,
            react_action: "add",
          }
      expect(response.status).to eq(400)
    end

    it "errors with invalid action" do
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "sdf",
          }
      expect(response.status).to eq(400)
    end

    it "creates a membership when reacting to channel without a membership record" do
      sign_in(user)

      expect {
        put "/chat/#{chat_channel_no_memberships.id}/react/#{chat_message_no_memberships.id}.json",
            params: {
              emoji: ":heart:",
              react_action: "add",
            }
      }.to change { Chat::UserChatChannelMembership.count }.by(1)
      expect(response.status).to eq(200)
    end

    it "errors when user tries to react to private channel they can't access" do
      sign_in(user)
      put "/chat/#{private_chat_channel.id}/react/#{private_chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
    end

    it "errors when the user tries to react to a read_only channel" do
      chat_channel.update(status: :read_only)
      sign_in(user)
      emoji = ":heart:"
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "add",
            }
      }.not_to change { chat_message.reactions.where(user: user, emoji: emoji).count }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("chat.errors.channel_modify_message_disallowed.#{chat_channel.status}"),
      )
    end

    it "errors when user is silenced" do
      UserSilencer.new(user).silence
      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":heart:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
    end

    it "errors when max unique reactions limit is reached" do
      Emoji
        .all
        .map(&:name)
        .take(29)
        .each { |emoji| chat_message.reactions.create(user: user, emoji: emoji) }

      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":wink:",
            react_action: "add",
          }
      expect(response.status).to eq(200)

      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: ":wave:",
            react_action: "add",
          }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("chat.errors.max_reactions_limit_reached"),
      )
    end

    it "does not error on new duplicate reactions" do
      another_user = Fabricate(:user)
      Emoji
        .all
        .map(&:name)
        .take(29)
        .each { |emoji| chat_message.reactions.create(user: another_user, emoji: emoji) }
      emoji = ":wink:"
      chat_message.reactions.create(user: another_user, emoji: emoji)

      sign_in(user)
      put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
          params: {
            emoji: emoji,
            react_action: "add",
          }
      expect(response.status).to eq(200)
    end

    it "adds a reaction record correctly" do
      sign_in(user)
      emoji = ":heart:"
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "add",
            }
      }.to change { chat_message.reactions.where(user: user, emoji: emoji).count }.by(1)
      expect(response.status).to eq(200)
    end

    it "removes a reaction record correctly" do
      sign_in(user)
      emoji = ":heart:"
      chat_message.reactions.create(user: user, emoji: emoji)
      expect {
        put "/chat/#{chat_channel.id}/react/#{chat_message.id}.json",
            params: {
              emoji: emoji,
              react_action: "remove",
            }
      }.to change { chat_message.reactions.where(user: user, emoji: emoji).count }.by(-1)
      expect(response.status).to eq(200)
    end
  end

  describe "invite_users" do
    fab!(:chat_channel) { Fabricate(:category_channel) }
    fab!(:chat_message) { Fabricate(:chat_message, chat_channel: chat_channel, user: admin) }
    fab!(:user2) { Fabricate(:user) }

    before do
      sign_in(admin)

      [user, user2].each { |u| u.user_option.update(chat_enabled: true) }
    end

    it "doesn't invite users who cannot chat" do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:admins]

      expect {
        put "/chat/#{chat_channel.id}/invite.json", params: { user_ids: [user.id] }
      }.not_to change {
        user.notifications.where(notification_type: Notification.types[:chat_invitation]).count
      }
    end

    it "creates an invitation notification for users who can chat" do
      expect {
        put "/chat/#{chat_channel.id}/invite.json", params: { user_ids: [user.id] }
      }.to change {
        user.notifications.where(notification_type: Notification.types[:chat_invitation]).count
      }.by(1)
      notification =
        user.notifications.where(notification_type: Notification.types[:chat_invitation]).last
      parsed_data = JSON.parse(notification[:data])
      expect(parsed_data["chat_channel_title"]).to eq(chat_channel.title(user))
      expect(parsed_data["chat_channel_slug"]).to eq(chat_channel.slug)
    end

    it "creates multiple invitations" do
      expect {
        put "/chat/#{chat_channel.id}/invite.json", params: { user_ids: [user.id, user2.id] }
      }.to change {
        Notification.where(
          notification_type: Notification.types[:chat_invitation],
          user_id: [user.id, user2.id],
        ).count
      }.by(2)
    end

    it "adds chat_message_id when param is present" do
      put "/chat/#{chat_channel.id}/invite.json",
          params: {
            user_ids: [user.id],
            chat_message_id: chat_message.id,
          }
      expect(JSON.parse(Notification.last.data)["chat_message_id"]).to eq(chat_message.id.to_s)
    end
  end

  describe "#dismiss_retention_reminder" do
    it "errors for anon" do
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      expect(response.status).to eq(403)
    end

    it "errors when chatable_type isn't present" do
      sign_in(user)
      post "/chat/dismiss-retention-reminder.json", params: {}
      expect(response.status).to eq(400)
    end

    it "errors when chatable_type isn't a valid option" do
      sign_in(user)
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "hi" }
      expect(response.status).to eq(400)
    end

    it "sets `dismissed_channel_retention_reminder` to true" do
      sign_in(user)
      expect {
        post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      }.to change { user.user_option.reload.dismissed_channel_retention_reminder }.to (true)
    end

    it "sets `dismissed_dm_retention_reminder` to true" do
      sign_in(user)
      expect {
        post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "DirectMessage" }
      }.to change { user.user_option.reload.dismissed_dm_retention_reminder }.to (true)
    end

    it "doesn't error if the fields are already true" do
      sign_in(user)
      user.user_option.update(
        dismissed_channel_retention_reminder: true,
        dismissed_dm_retention_reminder: true,
      )
      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "Category" }
      expect(response.status).to eq(200)

      post "/chat/dismiss-retention-reminder.json", params: { chatable_type: "DirectMessage" }
      expect(response.status).to eq(200)
    end
  end

  describe "#quote_messages" do
    fab!(:channel) { Fabricate(:category_channel, chatable: category, name: "Cool Chat") }
    let(:user2) { Fabricate(:user) }
    let(:message1) do
      Fabricate(
        :chat_message,
        user: user,
        chat_channel: channel,
        message: "an extremely insightful response :)",
      )
    end
    let(:message2) do
      Fabricate(:chat_message, user: user2, chat_channel: channel, message: "says you!")
    end
    let(:message3) { Fabricate(:chat_message, user: user, chat_channel: channel, message: "aw :(") }

    it "returns a 403 if the user can't chat" do
      SiteSetting.chat_allowed_groups = nil
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(403)
    end

    it "returns a 403 if the user can't see the channel" do
      category.update!(read_restricted: true)
      group = Fabricate(:group)
      CategoryGroup.create(
        group: group,
        category: category,
        permission_type: CategoryGroup.permission_types[:create_post],
      )
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(403)
    end

    it "returns a 404 for a not found channel" do
      channel.destroy
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(404)
    end

    it "quotes the message ids provided" do
      sign_in(user)
      post "/chat/#{channel.id}/quote.json",
           params: {
             message_ids: [message1.id, message2.id, message3.id],
           }
      expect(response.status).to eq(200)
      markdown = response.parsed_body["markdown"]
      expect(markdown).to eq(<<~EXPECTED)
      [chat quote="#{user.username};#{message1.id};#{message1.created_at.iso8601}" channel="Cool Chat" channelId="#{channel.id}" multiQuote="true" chained="true"]
      an extremely insightful response :)
      [/chat]

      [chat quote="#{user2.username};#{message2.id};#{message2.created_at.iso8601}" chained="true"]
      says you!
      [/chat]

      [chat quote="#{user.username};#{message3.id};#{message3.created_at.iso8601}" chained="true"]
      aw :(
      [/chat]
      EXPECTED
    end
  end

  describe "#flag" do
    fab!(:admin_chat_message) { Fabricate(:chat_message, user: admin, chat_channel: chat_channel) }
    fab!(:user_chat_message) { Fabricate(:chat_message, user: user, chat_channel: chat_channel) }

    fab!(:admin_dm_message) { Fabricate(:chat_message, user: admin, chat_channel: dm_chat_channel) }

    before do
      sign_in(user)
      Group.refresh_automatic_groups!
    end

    it "creates reviewable" do
      expect {
        put "/chat/flag.json",
            params: {
              chat_message_id: admin_chat_message.id,
              flag_type_id: ReviewableScore.types[:off_topic],
            }
      }.to change { Chat::ReviewableMessage.where(target: admin_chat_message).count }.by(1)
      expect(response.status).to eq(200)
    end

    it "errors for silenced users" do
      UserSilencer.new(user).silence

      put "/chat/flag.json",
          params: {
            chat_message_id: admin_chat_message.id,
            flag_type_id: ReviewableScore.types[:off_topic],
          }
      expect(response.status).to eq(403)
    end

    it "doesn't allow flagging your own message" do
      put "/chat/flag.json",
          params: {
            chat_message_id: user_chat_message.id,
            flag_type_id: ReviewableScore.types[:off_topic],
          }
      expect(response.status).to eq(403)
    end

    it "doesn't allow flagging messages in a read_only channel" do
      user_chat_message.chat_channel.update(status: :read_only)
      put "/chat/flag.json",
          params: {
            chat_message_id: admin_chat_message.id,
            flag_type_id: ReviewableScore.types[:off_topic],
          }

      expect(response.status).to eq(403)
    end

    it "doesn't allow flagging staff if SiteSetting.allow_flagging_staff is false" do
      SiteSetting.allow_flagging_staff = false
      put "/chat/flag.json",
          params: {
            chat_message_id: admin_chat_message.id,
            flag_type_id: ReviewableScore.types[:off_topic],
          }
      expect(response.status).to eq(403)
    end

    it "returns a 429 when the user attempts to flag more than 4 messages  in 1 minute" do
      RateLimiter.enable

      [message_1, message_2, message_3, message_4].each do |message|
        put "/chat/flag.json",
            params: {
              chat_message_id: message.id,
              flag_type_id: ReviewableScore.types[:off_topic],
            }
        expect(response.status).to eq(200)
      end

      put "/chat/flag.json",
          params: {
            chat_message_id: message_5.id,
            flag_type_id: ReviewableScore.types[:off_topic],
          }

      expect(response.status).to eq(429)
    end
  end

  describe "#set_draft" do
    fab!(:chat_channel) { Fabricate(:category_channel) }
    let(:dm_channel) { Fabricate(:direct_message_channel) }

    before { sign_in(user) }

    it "can create and destroy chat drafts" do
      expect {
        post "/chat/drafts.json", params: { chat_channel_id: chat_channel.id, data: "{}" }
      }.to change { Chat::Draft.count }.by(1)

      expect { post "/chat/drafts.json", params: { chat_channel_id: chat_channel.id } }.to change {
        Chat::Draft.count
      }.by(-1)
    end

    it "cannot create chat drafts for a category channel the user cannot access" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      chat_channel.update!(chatable: private_category)

      post "/chat/drafts.json", params: { chat_channel_id: chat_channel.id, data: "{}" }
      expect(response.status).to eq(403)

      GroupUser.create!(user: user, group: group)
      expect {
        post "/chat/drafts.json", params: { chat_channel_id: chat_channel.id, data: "{}" }
      }.to change { Chat::Draft.count }.by(1)
    end

    it "cannot create chat drafts for a direct message channel the user cannot access" do
      post "/chat/drafts.json", params: { chat_channel_id: dm_channel.id, data: "{}" }
      expect(response.status).to eq(403)

      Chat::DirectMessageUser.create(user: user, direct_message: dm_channel.chatable)
      expect {
        post "/chat/drafts.json", params: { chat_channel_id: dm_channel.id, data: "{}" }
      }.to change { Chat::Draft.count }.by(1)
    end

    it "cannot create a too long chat draft" do
      SiteSetting.max_chat_draft_length = 100

      post "/chat/drafts.json",
           params: {
             chat_channel_id: chat_channel.id,
             data: { value: "a" * (SiteSetting.max_chat_draft_length + 1) }.to_json,
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("chat.errors.draft_too_long")])
    end
  end

  describe "#message_link" do
    it "ensures message's channel can be seen" do
      channel = Fabricate(:category_channel, chatable: Fabricate(:category))
      message = Fabricate(:chat_message, chat_channel: channel)

      Guardian.any_instance.expects(:can_join_chat_channel?).with(channel)

      sign_in(Fabricate(:user))
      get "/chat/message/#{message.id}.json"
    end
  end

  describe "#lookup_message" do
    let!(:message) { Fabricate(:chat_message, chat_channel: channel) }
    let(:channel) { Fabricate(:direct_message_channel) }
    let(:chatable) { channel.chatable }
    fab!(:user) { Fabricate(:user) }

    before { sign_in(user) }

    it "ensures message's channel can be seen" do
      Guardian.any_instance.expects(:can_join_chat_channel?).with(channel)
      get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
    end

    context "when the message doesn’t belong to the channel" do
      let!(:message) { Fabricate(:chat_message) }

      it "returns a 404" do
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }

        expect(response.status).to eq(404)
      end
    end

    context "when the chat channel is for a category" do
      let(:channel) { Fabricate(:category_channel) }

      it "ensures the user can access that category" do
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)

        group = Fabricate(:group)
        chatable.update!(read_restricted: true)
        Fabricate(:category_group, group: group, category: chatable)
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
        expect(response.status).to eq(403)

        GroupUser.create!(user: user, group: group)
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)
      end
    end

    context "when the chat channel is for a direct message channel" do
      let(:channel) { Fabricate(:direct_message_channel) }

      it "ensures the user can access that direct message channel" do
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
        expect(response.status).to eq(403)

        Chat::DirectMessageUser.create!(user: user, direct_message: chatable)
        get "/chat/lookup/#{message.id}.json", params: { chat_channel_id: channel.id }
        expect(response.status).to eq(200)
        expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)
      end
    end
  end
end
