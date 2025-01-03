# frozen_string_literal: true

RSpec.describe Chat::UpdateMessage do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(upload_ids: upload_ids) }

    let(:upload_ids) { nil }

    it { is_expected.to validate_presence_of :message_id }

    context "when uploads are not provided" do
      it { is_expected.to validate_presence_of :message }
    end

    context "when uploads are provided" do
      let(:upload_ids) { "2,3" }

      it { is_expected.not_to validate_presence_of :message }
    end
  end

  describe "with validation" do
    let(:guardian) { Guardian.new(user1) }
    fab!(:admin1) { Fabricate(:admin) }
    fab!(:admin2) { Fabricate(:admin) }
    fab!(:user1) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) }
    fab!(:admin_group) do
      Fabricate(
        :public_group,
        users: [admin1, admin2],
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
      )
    end
    fab!(:user_without_memberships) { Fabricate(:user) }
    fab!(:public_chat_channel) { Fabricate(:category_channel) }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      Jobs.run_immediately!

      [admin1, admin2, user1, user2, user3, user4].each { |user| public_chat_channel.add(user) }
    end

    def create_chat_message(user, message, channel, upload_ids: nil)
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user,
        message: message,
        upload_ids: upload_ids,
        use_service: true,
      )
    end

    it "errors when length is less than `chat_minimum_message_length`" do
      SiteSetting.chat_minimum_message_length = 10
      og_message = "This won't be changed!"
      chat_message = create_chat_message(user1, og_message, public_chat_channel)
      new_message = "2 short"

      expect do
        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: new_message,
          },
        )
      end.to raise_error(ActiveRecord::RecordInvalid).with_message(
        "Validation failed: " +
          I18n.t(
            "chat.errors.minimum_length_not_met",
            { count: SiteSetting.chat_minimum_message_length },
          ),
      )

      expect(chat_message.reload.message).to eq(og_message)
    end

    it "errors when length is greater than `chat_maximum_message_length`" do
      SiteSetting.chat_maximum_message_length = 100
      og_message = "This won't be changed!"
      chat_message = create_chat_message(user1, og_message, public_chat_channel)
      new_message = "2 long" * 100

      expect do
        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: new_message,
          },
        )
      end.to raise_error(ActiveRecord::RecordInvalid).with_message(
        "Validation failed: " +
          I18n.t(
            "chat.errors.message_too_long",
            { count: SiteSetting.chat_maximum_message_length },
          ),
      )

      expect(chat_message.reload.message).to eq(og_message)
    end

    it "cleans message's content" do
      chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
      new_message = "bbbbb\n"

      described_class.call(
        guardian: guardian,
        params: {
          message_id: chat_message.id,
          message: new_message,
        },
      )
      expect(chat_message.reload.message).to eq("bbbbb")
    end

    context "when strip_whitespaces is disabled" do
      it "doesn't remove new lines" do
        chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
        new_message = "bbbbb\n"

        described_class.call(
          guardian: guardian,
          options: {
            strip_whitespaces: false,
          },
          params: {
            message_id: chat_message.id,
            message: new_message,
          },
        )
        expect(chat_message.reload.message).to eq("bbbbb\n")
      end
    end

    it "cooks the message" do
      chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
      new_message = "Change **to** this!"

      described_class.call(
        guardian: guardian,
        params: {
          message_id: chat_message.id,
          message: new_message,
        },
      )
      expect(chat_message.reload.cooked).to eq("<p>Change <strong>to</strong> this!</p>")
    end

    it "updates the excerpt" do
      chat_message = create_chat_message(user1, "This is a message", public_chat_channel)

      described_class.call(
        guardian: guardian,
        params: {
          message_id: chat_message.id,
          message: "Change to this!",
        },
      )
      expect(chat_message.reload.excerpt).to eq("Change to this!")
    end

    it "publishes a DiscourseEvent for updated messages" do
      chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
      events =
        DiscourseEvent.track_events do
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "Change to this!",
            },
          )
        end
      expect(events.map { _1[:event_name] }).to include(:chat_message_edited)
    end

    it "publishes updated message to message bus" do
      chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
      new_content = "New content"

      processed_message =
        MessageBus
          .track_publish("/chat/#{public_chat_channel.id}") do
            described_class.call(
              guardian: guardian,
              params: {
                message_id: chat_message.id,
                message: new_content,
              },
            )
          end
          .detect { |m| m.data["type"] == "edit" }
          .data

      expect(processed_message["chat_message"]["message"]).to eq(new_content)
    end

    context "with mentions" do
      it "sends notifications if a message was updated with new mentions" do
        message = create_chat_message(user1, "Mentioning @#{user2.username}", public_chat_channel)

        described_class.call(
          guardian: guardian,
          params: {
            message_id: message.id,
            message: "Mentioning @#{user2.username} and @#{user3.username}",
          },
        )

        mention = user3.chat_mentions.where(chat_message: message.id).first
        expect(mention.notifications.length).to be(1)
      end

      it "doesn't create mentions for already mentioned users" do
        message = "ping @#{user2.username} @#{user3.username}"
        chat_message = create_chat_message(user1, message, public_chat_channel)
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: message + " editedddd",
            },
          )
        }.not_to change { Chat::Mention.count }
      end

      it "doesn't create mention notification for users without access" do
        message = "ping"
        chat_message = create_chat_message(user1, message, public_chat_channel)

        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: message + " @#{user_without_memberships.username}",
          },
        )

        mention = user_without_memberships.chat_mentions.where(chat_message: chat_message).first
        expect(mention.notifications).to be_empty
      end

      it "destroys mentions that should be removed" do
        chat_message =
          create_chat_message(
            user1,
            "ping @#{user2.username} @#{user3.username}",
            public_chat_channel,
          )
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping @#{user3.username}",
            },
          )
        }.to change { user2.chat_mentions.count }.by(-1).and not_change {
                user3.chat_mentions.count
              }
      end

      it "creates new, leaves existing, and removes old mentions all at once" do
        chat_message =
          create_chat_message(
            user1,
            "ping @#{user2.username} @#{user3.username}",
            public_chat_channel,
          )
        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: "ping @#{user3.username} @#{user4.username}",
          },
        )

        expect(user2.chat_mentions.where(chat_message: chat_message)).not_to be_present
        expect(user3.chat_mentions.where(chat_message: chat_message)).to be_present
        expect(user4.chat_mentions.where(chat_message: chat_message)).to be_present
      end

      it "doesn't create mention notification in direct message for users without access" do
        result =
          Chat::CreateDirectMessageChannel.call(
            guardian: user1.guardian,
            params: {
              target_usernames: [user1.username, user2.username],
            },
          )
        service_failed!(result) if result.failure?
        direct_message_channel = result.channel
        message = create_chat_message(user1, "ping nobody", direct_message_channel)

        described_class.call(
          guardian: guardian,
          params: {
            message_id: message.id,
            message: "ping @#{admin1.username}",
          },
        )

        mention = admin1.chat_mentions.where(chat_message_id: message.id).first
        expect(mention.notifications).to be_empty
      end

      it "creates a chat_mention record without notification when self mentioning" do
        chat_message = create_chat_message(user1, "I will mention myself soon", public_chat_channel)
        new_content = "hello @#{user1.username}"

        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: new_content,
          },
        )

        mention = user1.chat_mentions.where(chat_message: chat_message).first
        expect(mention).to be_present
        expect(mention.notifications).to be_empty
      end

      it "adds mentioned user and their status to the message bus message" do
        SiteSetting.enable_user_status = true
        status = { description: "dentist", emoji: "tooth" }
        user2.set_status!(status[:description], status[:emoji])
        chat_message = create_chat_message(user1, "This will be updated", public_chat_channel)
        new_content = "Hey @#{user2.username}"

        processed_message =
          MessageBus
            .track_publish("/chat/#{public_chat_channel.id}") do
              described_class.call(
                guardian: guardian,
                params: {
                  message_id: chat_message.id,
                  message: new_content,
                },
              )
            end
            .detect { |m| m.data["type"] == "processed" }
            .data

        expect(processed_message["chat_message"]["mentioned_users"].count).to eq(1)

        mentioned_user = processed_message["chat_message"]["mentioned_users"][0]
        expect(mentioned_user["id"]).to eq(user2.id)
        expect(mentioned_user["username"]).to eq(user2.username)
        expect(mentioned_user["status"]).to be_present
        expect(mentioned_user["status"].symbolize_keys.slice(:description, :emoji)).to eq(status)
      end

      it "doesn't add mentioned user's status to the message bus message when status is disabled" do
        SiteSetting.enable_user_status = false
        user2.set_status!("dentist", "tooth")
        chat_message = create_chat_message(user1, "This will be updated", public_chat_channel)

        processed_message =
          MessageBus
            .track_publish("/chat/#{public_chat_channel.id}") do
              described_class.call(
                guardian: guardian,
                params: {
                  message_id: chat_message.id,
                  message: "Hey @#{user2.username}",
                },
              )
            end
            .detect { |m| m.data["type"] == "processed" }
            .data

        expect(processed_message["chat_message"]["mentioned_users"].count).to be(1)
        mentioned_user = processed_message["chat_message"]["mentioned_users"][0]

        expect(mentioned_user["status"]).to be_blank
      end

      context "when updating a mentioned user" do
        it "updates the mention record" do
          chat_message = create_chat_message(user1, "ping @#{user2.username}", public_chat_channel)

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping @#{user3.username}",
            },
          )

          user2_mentions = user2.chat_mentions.where(chat_message: chat_message)
          expect(user2_mentions.length).to be(0)

          user3_mentions = user3.chat_mentions.where(chat_message: chat_message)
          expect(user3_mentions.length).to be(1)
        end
      end

      context "when there are duplicate mentions" do
        it "creates a single mention record per user" do
          chat_message = create_chat_message(user1, "ping @#{user2.username}", public_chat_channel)

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping @#{user2.username} @#{user2.username} edited",
            },
          )

          expect(user2.chat_mentions.where(chat_message: chat_message).count).to eq(1)
        end
      end

      describe "with group mentions" do
        fab!(:group_1) do
          Fabricate(
            :public_group,
            users: [user1, user2],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        end
        fab!(:group_2) do
          Fabricate(
            :public_group,
            users: [user3, user4],
            mentionable_level: Group::ALIAS_LEVELS[:everyone],
          )
        end

        it "creates a mention record when a group was mentioned on message update" do
          chat_message = create_chat_message(user1, "ping nobody", public_chat_channel)

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping @#{group_1.name}",
            },
          )

          expect(group_1.chat_mentions.where(chat_message: chat_message).count).to be(1)
        end

        it "updates mention records when another group was mentioned on message update" do
          chat_message = create_chat_message(user1, "ping @#{group_1.name}", public_chat_channel)

          expect(chat_message.group_mentions.map(&:target_id)).to contain_exactly(group_1.id)

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping @#{group_2.name}",
            },
          )

          expect(chat_message.reload.group_mentions.map(&:target_id)).to contain_exactly(group_2.id)
        end

        it "deletes a mention record when a group mention was removed on message update" do
          chat_message = create_chat_message(user1, "ping @#{group_1.name}", public_chat_channel)

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "ping nobody anymore!",
            },
          )

          expect(group_1.chat_mentions.where(chat_message: chat_message).count).to be(0)
        end

        it "doesn't notify the second time users that has already been notified when creating the message" do
          group_user = Fabricate(:user)
          public_chat_channel.add(group_user)
          group =
            Fabricate(
              :public_group,
              users: [group_user],
              mentionable_level: Group::ALIAS_LEVELS[:everyone],
            )

          chat_message =
            create_chat_message(user1, "Mentioning @#{group.name}", public_chat_channel)
          expect(group_user.notifications.count).to be(1)
          notification_id = group_user.notifications.first.id

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "Update the message and still mention the same group @#{group.name}",
            },
          )

          expect(group_user.notifications.count).to be(1) # no new notifications has been created
          expect(group_user.notifications.first.id).to be(notification_id) # the existing notification hasn't been recreated
        end
      end

      describe "with @here mentions" do
        it "doesn't notify the second time users that has already been notified when creating the message" do
          user = Fabricate(:user)
          public_chat_channel.add(user)
          user.update!(last_seen_at: 4.minutes.ago)

          chat_message = create_chat_message(user1, "Mentioning @here", public_chat_channel)
          expect(user.notifications.count).to be(1)
          notification_id = user.notifications.first.id

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "Update the message and still mention @here",
            },
          )

          expect(user.notifications.count).to be(1) # no new notifications have been created
          expect(user.notifications.first.id).to be(notification_id) # the existing notification haven't been recreated
        end
      end

      describe "with @all mentions" do
        it "doesn't notify the second time users that has already been notified when creating the message" do
          user = Fabricate(:user)
          public_chat_channel.add(user)

          chat_message = create_chat_message(user1, "Mentioning @all", public_chat_channel)
          notification_id = user.notifications.first.id

          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "Update the message and still mention @all",
            },
          )

          expect(user.notifications.count).to be(1) # no new notifications have been created
          expect(user.notifications.first.id).to be(notification_id) # the existing notification haven't been recreated
        end
      end
    end

    it "creates a chat_message_revision record and sets last_editor_id for the message" do
      SiteSetting.chat_editing_grace_period = 10
      SiteSetting.chat_editing_grace_period_max_diff_low_trust = 5

      old_message = "It's a thrsday!"
      new_message = "Today is Thursday, it's almost the weekend already!"
      chat_message = create_chat_message(user1, old_message, public_chat_channel)
      described_class.call(
        guardian: guardian,
        params: {
          message_id: chat_message.id,
          message: new_message,
        },
      )

      revision = chat_message.revisions.last
      expect(revision.old_message).to eq(old_message)
      expect(revision.new_message).to eq(new_message)
      expect(revision.user_id).to eq(guardian.user.id)
      expect(chat_message.reload.last_editor_id).to eq(guardian.user.id)
    end

    describe "duplicates" do
      fab!(:upload1) { Fabricate(:upload, user: user1) }
      fab!(:upload2) { Fabricate(:upload, user: user1) }

      it "errors when editing the message to be the same as one that was posted recently" do
        chat_message_1 =
          create_chat_message(user1, "this is some chat message", public_chat_channel)
        chat_message_2 =
          create_chat_message(user1, "another different chat message here", public_chat_channel)

        chat_message_1.update!(created_at: 30.seconds.ago)
        chat_message_2.update!(created_at: 20.seconds.ago)

        expect do
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message_1.id,
              message: "another different chat message here",
            },
          )
        end.to raise_error(ActiveRecord::RecordInvalid).with_message(
          "Validation failed: " + I18n.t("chat.errors.duplicate_message"),
        )
      end

      it "does not count the message as a duplicate when editing leaves the message the same but changes uploads" do
        chat_message =
          create_chat_message(
            user1,
            "this is some chat message",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )
        chat_message.update!(created_at: 30.seconds.ago)

        updater =
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "this is some chat message",
              upload_ids: [upload2.id],
            },
          )
        expect(updater.message).to be_valid
        expect(chat_message.reload.uploads.count).to eq(1)
      end
    end

    describe "uploads" do
      fab!(:upload1) { Fabricate(:upload, user: user1) }
      fab!(:upload2) { Fabricate(:upload, user: user1) }

      it "does nothing if the passed in upload_ids match the existing upload_ids" do
        chat_message =
          create_chat_message(
            user1,
            "something",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [upload2.id, upload1.id],
            },
          )
        }.to not_change { UploadReference.count }
      end

      it "removes uploads that should be removed" do
        chat_message =
          create_chat_message(
            user1,
            "something",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )

        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [upload1.id],
            },
          )
        }.to change { UploadReference.where(upload_id: upload2.id).count }.by(-1)
      end

      it "removes all uploads if they should be removed" do
        chat_message =
          create_chat_message(
            user1,
            "something",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )

        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [],
            },
          )
        }.to change { UploadReference.where(target: chat_message).count }.by(-2)
      end

      it "adds one upload if none exist" do
        chat_message = create_chat_message(user1, "something", public_chat_channel)
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [upload1.id],
            },
          )
        }.to change { UploadReference.where(target: chat_message).count }.by(1)
      end

      it "adds multiple uploads if none exist" do
        chat_message = create_chat_message(user1, "something", public_chat_channel)
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [upload1.id, upload2.id],
            },
          )
        }.to change { UploadReference.where(target: chat_message).count }.by(2)
      end

      it "doesn't remove existing uploads when upload ids that do not exist are passed in" do
        chat_message =
          create_chat_message(user1, "something", public_chat_channel, upload_ids: [upload1.id])
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message,
              message: "I guess this is different",
              upload_ids: [0],
            },
          )
        }.to not_change { UploadReference.where(target: chat_message).count }
      end

      it "doesn't add uploads if `chat_allow_uploads` is false" do
        SiteSetting.chat_allow_uploads = false
        chat_message = create_chat_message(user1, "something", public_chat_channel)
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [upload1.id, upload2.id],
            },
          )
        }.to not_change { UploadReference.where(target: chat_message).count }
      end

      it "doesn't remove existing uploads if `chat_allow_uploads` is false" do
        SiteSetting.chat_allow_uploads = false
        chat_message =
          create_chat_message(
            user1,
            "something",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )
        expect {
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "I guess this is different",
              upload_ids: [],
            },
          )
        }.to not_change { UploadReference.where(target: chat_message).count }
      end

      it "updates if upload is present even if length is less than `chat_minimum_message_length`" do
        chat_message =
          create_chat_message(
            user1,
            "something",
            public_chat_channel,
            upload_ids: [upload1.id, upload2.id],
          )
        SiteSetting.chat_minimum_message_length = 10
        new_message = "hi :)"
        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: new_message,
            upload_ids: [upload1.id],
          },
        )
        expect(chat_message.reload.message).to eq(new_message)
      end
    end

    context "when the message is in a thread" do
      fab!(:message) do
        Fabricate(
          :chat_message,
          user: user1,
          chat_channel: public_chat_channel,
          thread: Fabricate(:chat_thread, channel: public_chat_channel),
        )
      end

      it "publishes a MessageBus event to update the original message metadata" do
        messages =
          MessageBus.track_publish("/chat/#{public_chat_channel.id}") do
            described_class.call(
              guardian: guardian,
              params: {
                message_id: message.id,
                message: "some new updated content",
              },
            )
          end
        expect(
          messages.find { |m| m.data["type"] == "update_thread_original_message" },
        ).to be_present
      end
    end

    describe "watched words" do
      fab!(:watched_word)
      let!(:censored_word) do
        Fabricate(:watched_word, word: "test", action: WatchedWord.actions[:censor])
      end

      it "errors when a blocked word is present" do
        chat_message = create_chat_message(user1, "something", public_chat_channel)
        msg = "Validation failed: " + I18n.t("contains_blocked_word", { word: watched_word.word })

        expect do
          described_class.call(
            guardian: guardian,
            params: {
              message_id: chat_message.id,
              message: "bad word - #{watched_word.word}",
            },
          )
        end.to raise_error(ActiveRecord::RecordInvalid).with_message(msg)

        expect(chat_message.reload.message).not_to eq("bad word - #{watched_word.word}")
      end

      it "hides censored word within the excerpt" do
        chat_message = create_chat_message(user1, "something", public_chat_channel)

        described_class.call(
          guardian: guardian,
          params: {
            message_id: chat_message.id,
            message: "bad word - #{censored_word.word}",
          },
        )

        expect(chat_message.reload.excerpt).to eq("bad word - ■■■■")
      end
    end

    describe "channel statuses" do
      fab!(:message) { Fabricate(:chat_message, user: user1, chat_channel: public_chat_channel) }

      def update_message(user)
        message.update!(user: user)
        described_class.call(
          guardian: Guardian.new(user),
          params: {
            message_id: message.id,
            message: "I guess this is different",
          },
        )
      end

      context "when channel is closed" do
        before { public_chat_channel.update(status: :closed) }

        it "errors when trying to update the message for non-staff" do
          update_message(user1)
          expect(message.reload.message).not_to eq("I guess this is different")
        end

        it "does not error when trying to create a message for staff" do
          update_message(admin1)
          expect(message.reload.message).to eq("I guess this is different")
        end
      end

      context "when channel is read_only" do
        before { public_chat_channel.update(status: :read_only) }

        it "errors when trying to update the message for all users" do
          update_message(user1)
          expect(message.reload.message).not_to eq("I guess this is different")

          update_message(admin1)
          expect(message.reload.message).not_to eq("I guess this is different")
        end
      end

      context "when channel is archived" do
        before { public_chat_channel.update(status: :archived) }

        it "errors when trying to update the message for all users" do
          update_message(user1)
          expect(message.reload.message).not_to eq("I guess this is different")

          update_message(admin1)
          expect(message.reload.message).not_to eq("I guess this is different")
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, options:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel) }
    fab!(:upload_1) { Fabricate(:upload, user: current_user) }
    fab!(:message_1) do
      Fabricate(
        :chat_message,
        chat_channel_id: channel_1.id,
        message: "old",
        upload_ids: [upload_1.id],
        user: current_user,
      )
    end

    let(:guardian) { current_user.guardian }
    let(:message) { "new" }
    let(:message_id) { message_1.id }
    let(:upload_ids) { [upload_1.id] }
    let(:params) { { message_id: message_id, message: message, upload_ids: upload_ids } }
    let(:dependencies) { { guardian: guardian } }
    let(:options) { {} }

    before do
      SiteSetting.chat_editing_grace_period = 30
      SiteSetting.chat_editing_grace_period_max_diff_low_trust = 10
      SiteSetting.chat_editing_grace_period_max_diff_high_trust = 40

      channel_1.add(current_user)
    end

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "updates the message" do
        expect(result.message.message).to eq("new")
      end

      it "updates the uploads" do
        upload_1 = Fabricate(:upload, user: current_user)
        upload_2 = Fabricate(:upload, user: current_user)
        params[:upload_ids] = [upload_1.id, upload_2.id]

        expect(result.message.upload_ids).to contain_exactly(upload_1.id, upload_2.id)
      end

      it "keeps the existing uploads" do
        expect(result.message.upload_ids).to eq([upload_1.id])
      end

      it "does not update last editor" do
        # message can only be updated by the original author
        message_1.update!(last_editor: Discourse.system_user)

        expect { result }.to not_change { result.message.last_editor_id }
      end

      it "can enqueue a job to process message" do
        options[:process_inline] = false
        expect_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
      end

      it "can process a message inline" do
        options[:process_inline] = true
        Jobs::Chat::ProcessMessage.any_instance.expects(:execute).once
        expect_not_enqueued_with(job: Jobs::Chat::ProcessMessage) { result }
      end

      context "when user is a bot" do
        fab!(:bot) { Discourse.system_user }
        let(:guardian) { Guardian.new(bot) }

        it "creates the membership" do
          expect { result }.to change { channel_1.membership_for(bot) }.from(nil).to(be_present)
        end
      end
    end

    context "when params are not valid" do
      before { params.delete(:message_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when user can't modify a channel message" do
      before { channel_1.update!(status: :read_only) }

      it { is_expected.to fail_a_policy(:can_modify_channel_message) }
    end

    context "when user is not member of the channel" do
      let(:message_id) { Fabricate(:chat_message).id }

      it { is_expected.to fail_to_find_a_model(:membership) }
    end

    context "when edit grace period" do
      let(:low_trust_char_limit) { SiteSetting.chat_editing_grace_period_max_diff_low_trust }
      let(:high_trust_char_limit) { SiteSetting.chat_editing_grace_period_max_diff_high_trust }

      it "does not create a revision when under (n) seconds" do
        freeze_time 5.seconds.from_now
        message_1.update!(message: "hello")

        expect { result }.to not_change { Chat::MessageRevision.count }
      end

      it "does not create a revision when under (n) chars" do
        message_1.update!(message: "hi :)")

        expect { result }.to not_change { Chat::MessageRevision.count }
      end

      it "creates a revision when over (n) seconds" do
        freeze_time 40.seconds.from_now
        message_1.update!(message: "welcome")

        expect { result }.to change { Chat::MessageRevision.count }.by(1)
      end

      it "creates a revision when over (n) chars" do
        message_1.update!(message: "a" * (low_trust_char_limit + 1))

        expect { result }.to change { Chat::MessageRevision.count }.by(1)
      end

      it "allows trusted users to make larger edits without creating revision" do
        current_user.update!(trust_level: TrustLevel[4])
        message_1.update!(message: "a" * (low_trust_char_limit + 1))

        expect { result }.to not_change { Chat::MessageRevision.count }
      end

      it "creates a revision when over (n) chars for high trust users" do
        current_user.update!(trust_level: TrustLevel[4])

        message_1.update!(message: "a" * (high_trust_char_limit + 1))
        expect { result }.to change { Chat::MessageRevision.count }.by(1)
      end
    end
  end
end
