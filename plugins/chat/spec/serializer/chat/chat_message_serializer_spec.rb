# frozen_string_literal: true

describe Chat::MessageSerializer do
  subject(:serializer) { described_class.new(message_1, scope: guardian, root: nil) }

  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:message_poster) { Fabricate(:user) }
  fab!(:message_1) { Fabricate(:chat_message, user: message_poster, chat_channel: chat_channel) }
  fab!(:guardian_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:guardian) { Guardian.new(guardian_user) }

  describe "#mentioned_users" do
    it "is limited by max_mentions_per_chat_message setting" do
      Fabricate.times(2, :user_chat_mention, chat_message: message_1)
      SiteSetting.max_mentions_per_chat_message = 1

      expect(serializer.as_json[:mentioned_users].length).to eq(1)
    end
  end

  describe "#reactions" do
    fab!(:custom_emoji) { CustomEmoji.create!(name: "trout", upload: Fabricate(:upload)) }
    fab!(:reaction_1) do
      Fabricate(:chat_message_reaction, chat_message: message_1, emoji: custom_emoji.name)
    end

    context "when an emoji used in a reaction has been destroyed" do
      it "doesn’t return the reaction" do
        Emoji.clear_cache

        trout_reaction = serializer.as_json[:reactions].find { |r| r[:emoji] == "trout" }
        expect(trout_reaction).to be_present

        custom_emoji.destroy!
        Emoji.clear_cache

        trout_reaction = serializer.as_json[:reactions].find { |r| r[:emoji] == "trout" }
        expect(trout_reaction).to_not be_present
      end
    end
  end

  describe "#excerpt" do
    it "censors words" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor])
      message = Fabricate(:chat_message, use_service: true, message: "ok #{watched_word.word}")
      serializer = described_class.new(message, scope: guardian, root: nil)

      expect(serializer.as_json[:excerpt]).to eq("ok ■■■■■")
    end
  end

  describe "#user" do
    context "when user has been destroyed" do
      it "returns a placeholder user" do
        message_1.user.destroy!
        message_1.reload

        expect(serializer.as_json[:user][:username]).to eq(I18n.t("chat.deleted_chat_username"))
      end
    end

    context "with user status" do
      it "adds status to user if status is enabled" do
        message_1.user.set_status!("test", "heart")
        SiteSetting.enable_user_status = true
        json = serializer.as_json
        expect(json[:user][:status]).to be_present
      end

      it "does not add status to user if status is disabled" do
        SiteSetting.enable_user_status = false
        json = serializer.as_json
        expect(json[:user][:status]).to be_nil
      end
    end
  end

  describe "#deleted_at" do
    context "when user has been destroyed" do
      it "has a deleted at date" do
        message_1.user.destroy!
        message_1.reload

        expect(serializer.as_json[:deleted_at]).to(be_within(1.second).of(Time.zone.now))
      end

      it "is marked as deleted by system user" do
        message_1.user.destroy!
        message_1.reload

        expect(serializer.as_json[:deleted_by_id]).to eq(Discourse.system_user.id)
      end
    end
  end

  describe "#available_flags" do
    context "when flagging on a regular channel" do
      let(:options) { { scope: guardian, root: nil, chat_channel: message_1.chat_channel } }

      it "returns an empty list if the user already flagged the message" do
        reviewable = Fabricate(:chat_reviewable_message, target: message_1)

        serialized =
          described_class.new(
            message_1,
            options.merge(
              reviewable_ids: {
                message_1.id => reviewable.id,
              },
              user_flag_statuses: {
                message_1.id => ReviewableScore.statuses[:pending],
              },
            ),
          ).as_json

        expect(serialized[:available_flags]).to be_empty
      end

      it "return available flags if staff already reviewed the previous flag" do
        reviewable = Fabricate(:chat_reviewable_message, target: message_1)

        serialized =
          described_class.new(
            message_1,
            options.merge(
              reviewable_ids: {
                message_1.id => reviewable.id,
              },
              user_flag_statuses: {
                message_1.id => ReviewableScore.statuses[:ignored],
              },
            ),
          ).as_json

        expect(serialized[:available_flags]).to be_present
      end

      it "doesn't include notify_user for self-flags" do
        guardian_1 = Guardian.new(message_1.user)

        serialized =
          described_class.new(message_1, options.merge(scope: Guardian.new(message_poster))).as_json

        expect(serialized[:available_flags]).not_to include(:notify_user)
      end

      it "doesn't include the notify_user flag for bot messages" do
        message_1.update!(user: Discourse.system_user)

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).not_to include(:notify_user)
      end

      it "returns an empty list for anons" do
        serialized = described_class.new(message_1, options.merge(scope: Guardian.new)).as_json

        expect(serialized[:available_flags]).to be_empty
      end

      it "returns an empty list for silenced users" do
        guardian.user.update!(silenced_till: 1.month.from_now)

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).to be_empty
      end

      it "returns an empty list if the message was deleted" do
        message_1.trash!

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).to be_empty
      end

      it "doesn't include notify_user if they are not in a PM allowed group" do
        SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).not_to include(:notify_user)
      end

      it "returns an empty list if the user needs a higher TL to flag" do
        guardian.user.change_trust_level!(TrustLevel[2])
        SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).to be_empty
      end
    end

    context "when flagging DMs" do
      fab!(:dm_channel) do
        Fabricate(:direct_message_channel, users: [guardian_user, message_poster])
      end
      fab!(:dm_message) { Fabricate(:chat_message, user: message_poster, chat_channel: dm_channel) }

      let(:options) { { scope: guardian, root: nil, chat_channel: dm_channel } }

      it "doesn't include the notify_user flag type" do
        serialized = described_class.new(dm_message, options).as_json

        expect(serialized[:available_flags]).not_to include(:notify_user)
      end

      it "doesn't include the notify_moderators flag type" do
        serialized = described_class.new(dm_message, options).as_json

        expect(serialized[:available_flags]).not_to include(:notify_moderators)
      end

      it "includes other flags" do
        serialized = described_class.new(dm_message, options).as_json

        expect(serialized[:available_flags]).to include(:spam)
      end

      it "fallbacks to the object association when the chat_channel option is nil" do
        serialized = described_class.new(dm_message, options.except(:chat_channel)).as_json

        expect(serialized[:available_flags]).not_to include(:notify_moderators)
      end
    end
  end

  describe "#mentioned_users" do
    it "doesn't fail if mentioned user was deleted" do
      mentioned_user = Fabricate(:user)
      message =
        Fabricate(
          :chat_message,
          message:
            "here should be a mention, but since we're fabricating objects it doesn't matter",
        )
      Fabricate(:user_chat_mention, chat_message: message, user: mentioned_user)

      mentioned_user.destroy!
      message.reload
      serializer = described_class.new(message, scope: guardian, root: nil)

      expect { serializer.as_json }.not_to raise_error
      expect(serializer.as_json[:mentioned_users]).to be_empty
    end

    context "with user status" do
      fab!(:user_status)
      fab!(:mentioned_user) { Fabricate(:user, user_status: user_status) }
      fab!(:message) do
        Fabricate(
          :chat_message,
          message:
            "there should be a mention here, but since we're fabricating objects it doesn't matter",
        )
      end
      fab!(:chat_mention) do
        Fabricate(:user_chat_mention, chat_message: message, user: mentioned_user)
      end

      it "adds status to mentioned users when status is enabled" do
        SiteSetting.enable_user_status = true

        serializer = described_class.new(message, scope: guardian, root: nil)
        json = serializer.as_json

        expect(json[:mentioned_users][0][:status]).not_to be_nil
        expect(json[:mentioned_users][0][:status][:description]).to eq(user_status.description)
        expect(json[:mentioned_users][0][:status][:emoji]).to eq(user_status.emoji)
      end

      it "does not add status to mentioned users when status is enabled" do
        SiteSetting.enable_user_status = false

        serializer = described_class.new(message, scope: guardian, root: nil)
        json = serializer.as_json

        expect(json[:mentioned_users][0][:status]).to be_nil
      end
    end
  end

  describe "threading data" do
    before { message_1.update!(thread: Fabricate(:chat_thread, channel: chat_channel)) }

    context "when the channel has threading_enabled false" do
      before { chat_channel.update!(threading_enabled: false) }

      it "does not include thread data" do
        serialized = described_class.new(message_1, scope: guardian, root: nil).as_json
        expect(serialized).not_to have_key(:thread_id)
      end
    end

    context "when the channel has threading_enabled true" do
      before { chat_channel.update!(threading_enabled: true) }

      it "does include thread data" do
        serialized = described_class.new(message_1, scope: guardian, root: nil).as_json
        expect(serialized).to have_key(:thread_id)
      end
    end
  end
end
