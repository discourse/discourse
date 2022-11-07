# frozen_string_literal: true

require "rails_helper"

describe ChatMessageSerializer do
  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:message_poster) { Fabricate(:user) }
  fab!(:message_1) { Fabricate(:chat_message, user: message_poster, chat_channel: chat_channel) }
  fab!(:guardian_user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(guardian_user) }

  subject { described_class.new(message_1, scope: guardian, root: nil) }

  describe "#reactions" do
    fab!(:custom_emoji) { CustomEmoji.create!(name: "trout", upload: Fabricate(:upload)) }
    fab!(:reaction_1) do
      Fabricate(:chat_message_reaction, chat_message: message_1, emoji: custom_emoji.name)
    end

    context "when an emoji used in a reaction has been destroyed" do
      it "doesn’t return the reaction" do
        Emoji.clear_cache

        expect(subject.as_json[:reactions]["trout"]).to be_present

        custom_emoji.destroy!
        Emoji.clear_cache

        expect(subject.as_json[:reactions]["trout"]).to_not be_present
      end
    end
  end

  describe "#excerpt" do
    it "censors words" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor])
      message = Fabricate(:chat_message, message: "ok #{watched_word.word}")
      serializer = described_class.new(message, scope: guardian, root: nil)

      expect(serializer.as_json[:excerpt]).to eq("ok ■■■■■")
    end
  end

  describe "#user" do
    context "when user has been destroyed" do
      it "returns a placeholder user" do
        message_1.user.destroy!
        message_1.reload

        expect(subject.as_json[:user][:username]).to eq(I18n.t("chat.deleted_chat_username"))
      end
    end
  end

  describe "#deleted_at" do
    context "when user has been destroyed" do
      it "has a deleted at date" do
        message_1.user.destroy!
        message_1.reload

        expect(subject.as_json[:deleted_at]).to(be_within(1.second).of(Time.zone.now))
      end

      it "is marked as deleted by system user" do
        message_1.user.destroy!
        message_1.reload

        expect(subject.as_json[:deleted_by_id]).to eq(Discourse.system_user.id)
      end
    end
  end

  describe "#available_flags" do
    before { Group.refresh_automatic_groups! }

    context "when flagging on a regular channel" do
      let(:options) { { scope: guardian, root: nil, chat_channel: message_1.chat_channel } }

      it "returns an empty list if the user already flagged the message" do
        reviewable = Fabricate(:reviewable_chat_message, target: message_1)

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
        reviewable = Fabricate(:reviewable_chat_message, target: message_1)

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
        Group.refresh_automatic_groups!

        serialized = described_class.new(message_1, options).as_json

        expect(serialized[:available_flags]).not_to include(:notify_user)
      end

      it "returns an empty list if the user needs a higher TL to flag" do
        guardian.user.update!(trust_level: TrustLevel[2])
        SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]
        Group.refresh_automatic_groups!

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
end
