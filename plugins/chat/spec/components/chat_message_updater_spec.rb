# frozen_string_literal: true

require "rails_helper"

describe Chat::ChatMessageUpdater do
  let(:guardian) { Guardian.new(user1) }
  fab!(:admin1) { Fabricate(:admin) }
  fab!(:admin2) { Fabricate(:admin) }
  fab!(:user1) { Fabricate(:user) }
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
    SiteSetting.chat_duplicate_message_sensitivity = 0
    Jobs.run_immediately!

    [admin1, admin2, user1, user2, user3, user4].each do |user|
      Fabricate(:user_chat_channel_membership, chat_channel: public_chat_channel, user: user)
    end
    Group.refresh_automatic_groups!
    @direct_message_channel =
      Chat::DirectMessageChannelCreator.create!(acting_user: user1, target_users: [user1, user2])
  end

  def create_chat_message(user, message, channel, upload_ids: nil)
    creator =
      Chat::ChatMessageCreator.create(
        chat_channel: channel,
        user: user,
        in_reply_to_id: nil,
        content: message,
        upload_ids: upload_ids,
      )
    creator.chat_message
  end

  it "errors when length is less than `chat_minimum_message_length`" do
    SiteSetting.chat_minimum_message_length = 10
    og_message = "This won't be changed!"
    chat_message = create_chat_message(user1, og_message, public_chat_channel)
    new_message = "2 short"

    updater =
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: new_message,
      )
    expect(updater.failed?).to eq(true)
    expect(updater.error.message).to match(
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

    updater =
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: new_message,
      )
    expect(updater.failed?).to eq(true)
    expect(updater.error.message).to match(
      I18n.t("chat.errors.message_too_long", { count: SiteSetting.chat_maximum_message_length }),
    )
    expect(chat_message.reload.message).to eq(og_message)
  end

  it "errors if a user other than the message user is trying to edit the message" do
    og_message = "This won't be changed!"
    chat_message = create_chat_message(user1, og_message, public_chat_channel)
    new_message = "2 short"
    updater =
      Chat::ChatMessageUpdater.update(
        guardian: Guardian.new(Fabricate(:user)),
        chat_message: chat_message,
        new_content: new_message,
      )
    expect(updater.failed?).to eq(true)
    expect(updater.error).to match(Discourse::InvalidAccess)
  end

  it "it updates a messages content" do
    chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
    new_message = "Change to this!"

    Chat::ChatMessageUpdater.update(
      guardian: guardian,
      chat_message: chat_message,
      new_content: new_message,
    )
    expect(chat_message.reload.message).to eq(new_message)
  end

  it "publishes a DiscourseEvent for updated messages" do
    chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
    events =
      DiscourseEvent.track_events do
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "Change to this!",
        )
      end
    expect(events.map { _1[:event_name] }).to include(:chat_message_edited)
  end

  it "creates mention notifications for unmentioned users" do
    chat_message = create_chat_message(user1, "This will be changed", public_chat_channel)
    expect {
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content:
          "this is a message with @system @mentions @#{user2.username} and @#{user3.username}",
      )
    }.to change { user2.chat_mentions.count }.by(1).and change { user3.chat_mentions.count }.by(1)
  end

  it "doesn't create mentions for already mentioned users" do
    message = "ping @#{user2.username} @#{user3.username}"
    chat_message = create_chat_message(user1, message, public_chat_channel)
    expect {
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: message + " editedddd",
      )
    }.not_to change { ChatMention.count }
  end

  it "doesn't create mentions for users without access" do
    message = "ping"
    chat_message = create_chat_message(user1, message, public_chat_channel)

    expect {
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: message + " @#{user_without_memberships.username}",
      )
    }.not_to change { ChatMention.count }
  end

  it "destroys mention notifications that should be removed" do
    chat_message =
      create_chat_message(user1, "ping @#{user2.username} @#{user3.username}", public_chat_channel)
    expect {
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: "ping @#{user3.username}",
      )
    }.to change { user2.chat_mentions.count }.by(-1).and not_change { user3.chat_mentions.count }
  end

  it "creates new, leaves existing, and removes old mentions all at once" do
    chat_message =
      create_chat_message(user1, "ping @#{user2.username} @#{user3.username}", public_chat_channel)
    Chat::ChatMessageUpdater.update(
      guardian: guardian,
      chat_message: chat_message,
      new_content: "ping @#{user3.username} @#{user4.username}",
    )

    expect(user2.chat_mentions.where(chat_message: chat_message)).not_to be_present
    expect(user3.chat_mentions.where(chat_message: chat_message)).to be_present
    expect(user4.chat_mentions.where(chat_message: chat_message)).to be_present
  end

  it "does not create new mentions in direct message for users who don't have access" do
    chat_message = create_chat_message(user1, "ping nobody", @direct_message_channel)
    expect {
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: "ping @#{admin1.username}",
      )
    }.not_to change { ChatMention.count }
  end

  describe "group mentions" do
    it "creates group mentions on update" do
      chat_message = create_chat_message(user1, "ping nobody", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "ping @#{admin_group.name}",
        )
      }.to change { ChatMention.where(chat_message: chat_message).count }.by(2)

      expect(admin1.chat_mentions.where(chat_message: chat_message)).to be_present
      expect(admin2.chat_mentions.where(chat_message: chat_message)).to be_present
    end

    it "doesn't duplicate mentions when the user is already direct mentioned and then group mentioned" do
      chat_message = create_chat_message(user1, "ping @#{admin2.username}", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "ping @#{admin_group.name} @#{admin2.username}",
        )
      }.to change { admin1.chat_mentions.count }.by(1).and not_change { admin2.chat_mentions.count }
    end

    it "deletes old mentions when group mention is removed" do
      chat_message = create_chat_message(user1, "ping @#{admin_group.name}", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "ping nobody anymore!",
        )
      }.to change { ChatMention.where(chat_message: chat_message).count }.by(-2)

      expect(admin1.chat_mentions.where(chat_message: chat_message)).not_to be_present
      expect(admin2.chat_mentions.where(chat_message: chat_message)).not_to be_present
    end
  end

  it "creates a chat_message_revision record and sets last_editor_id for the message" do
    old_message = "It's a thrsday!"
    new_message = "It's a thursday!"
    chat_message = create_chat_message(user1, old_message, public_chat_channel)
    Chat::ChatMessageUpdater.update(
      guardian: guardian,
      chat_message: chat_message,
      new_content: new_message,
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

    before do
      SiteSetting.chat_duplicate_message_sensitivity = 1.0
      public_chat_channel.update!(user_count: 50)
    end

    it "errors when editing the message to be the same as one that was posted recently" do
      chat_message_1 = create_chat_message(user1, "this is some chat message", public_chat_channel)
      chat_message_2 =
        create_chat_message(
          Fabricate(:user),
          "another different chat message here",
          public_chat_channel,
        )

      chat_message_1.update!(created_at: 30.seconds.ago)
      chat_message_2.update!(created_at: 20.seconds.ago)

      updater =
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message_1,
          new_content: "another different chat message here",
        )
      expect(updater.failed?).to eq(true)
      expect(updater.error.message).to eq(I18n.t("chat.errors.duplicate_message"))
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
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "this is some chat message",
          upload_ids: [upload2.id],
        )
      expect(updater.failed?).to eq(false)
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
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [upload2.id, upload1.id],
        )
      }.to not_change { chat_upload_count }.and not_change { UploadReference.count }
    end

    it "removes uploads that should be removed" do
      chat_message =
        create_chat_message(
          user1,
          "something",
          public_chat_channel,
          upload_ids: [upload1.id, upload2.id],
        )

      # TODO (martin) Remove this when we remove ChatUpload completely, 2023-04-01
      DB.exec(<<~SQL)
        INSERT INTO chat_uploads(upload_id, chat_message_id, created_at, updated_at)
        VALUES(#{upload1.id}, #{chat_message.id}, NOW(), NOW())
      SQL
      DB.exec(<<~SQL)
        INSERT INTO chat_uploads(upload_id, chat_message_id, created_at, updated_at)
        VALUES(#{upload2.id}, #{chat_message.id}, NOW(), NOW())
      SQL
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [upload1.id],
        )
      }.to change { chat_upload_count([upload2]) }.by(-1).and change {
              UploadReference.where(upload_id: upload2.id).count
            }.by(-1)
    end

    it "removes all uploads if they should be removed" do
      chat_message =
        create_chat_message(
          user1,
          "something",
          public_chat_channel,
          upload_ids: [upload1.id, upload2.id],
        )

      # TODO (martin) Remove this when we remove ChatUpload completely, 2023-04-01
      DB.exec(<<~SQL)
        INSERT INTO chat_uploads(upload_id, chat_message_id, created_at, updated_at)
        VALUES(#{upload1.id}, #{chat_message.id}, NOW(), NOW())
      SQL
      DB.exec(<<~SQL)
        INSERT INTO chat_uploads(upload_id, chat_message_id, created_at, updated_at)
        VALUES(#{upload2.id}, #{chat_message.id}, NOW(), NOW())
      SQL
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [],
        )
      }.to change { chat_upload_count([upload1, upload2]) }.by(-2).and change {
              UploadReference.where(target: chat_message).count
            }.by(-2)
    end

    it "adds one upload if none exist" do
      chat_message = create_chat_message(user1, "something", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [upload1.id],
        )
      }.to not_change { chat_upload_count([upload1]) }.and change {
              UploadReference.where(target: chat_message).count
            }.by(1)
    end

    it "adds multiple uploads if none exist" do
      chat_message = create_chat_message(user1, "something", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [upload1.id, upload2.id],
        )
      }.to not_change { chat_upload_count([upload1, upload2]) }.and change {
              UploadReference.where(target: chat_message).count
            }.by(2)
    end

    it "doesn't remove existing uploads when upload ids that do not exist are passed in" do
      chat_message =
        create_chat_message(user1, "something", public_chat_channel, upload_ids: [upload1.id])
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [0],
        )
      }.to not_change { chat_upload_count }.and not_change {
              UploadReference.where(target: chat_message).count
            }
    end

    it "doesn't add uploads if `chat_allow_uploads` is false" do
      SiteSetting.chat_allow_uploads = false
      chat_message = create_chat_message(user1, "something", public_chat_channel)
      expect {
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [upload1.id, upload2.id],
        )
      }.to not_change { chat_upload_count([upload1, upload2]) }.and not_change {
              UploadReference.where(target: chat_message).count
            }
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
        Chat::ChatMessageUpdater.update(
          guardian: guardian,
          chat_message: chat_message,
          new_content: "I guess this is different",
          upload_ids: [],
        )
      }.to not_change { chat_upload_count }.and not_change {
              UploadReference.where(target: chat_message).count
            }
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
      Chat::ChatMessageUpdater.update(
        guardian: guardian,
        chat_message: chat_message,
        new_content: new_message,
        upload_ids: [upload1.id],
      )
      expect(chat_message.reload.message).to eq(new_message)
    end
  end

  describe "watched words" do
    fab!(:watched_word) { Fabricate(:watched_word) }

    it "errors when a blocked word is present" do
      chat_message = create_chat_message(user1, "something", public_chat_channel)
      creator =
        Chat::ChatMessageCreator.create(
          chat_channel: public_chat_channel,
          user: user1,
          content: "bad word - #{watched_word.word}",
        )
      expect(creator.failed?).to eq(true)
      expect(creator.error.message).to match(
        I18n.t("contains_blocked_word", { word: watched_word.word }),
      )
    end
  end

  describe "channel statuses" do
    fab!(:message) { Fabricate(:chat_message, user: user1, chat_channel: public_chat_channel) }

    def update_message(user)
      message.update(user: user)
      Chat::ChatMessageUpdater.update(
        guardian: Guardian.new(user),
        chat_message: message,
        new_content: "I guess this is different",
      )
    end

    context "when channel is closed" do
      before { public_chat_channel.update(status: :closed) }

      it "errors when trying to update the message for non-staff" do
        updater = update_message(user1)
        expect(updater.failed?).to eq(true)
        expect(updater.error.message).to eq(
          I18n.t("chat.errors.channel_modify_message_disallowed.closed"),
        )
      end

      it "does not error when trying to create a message for staff" do
        update_message(admin1)
        expect(message.reload.message).to eq("I guess this is different")
      end
    end

    context "when channel is read_only" do
      before { public_chat_channel.update(status: :read_only) }

      it "errors when trying to update the message for all users" do
        updater = update_message(user1)
        expect(updater.failed?).to eq(true)
        expect(updater.error.message).to eq(
          I18n.t("chat.errors.channel_modify_message_disallowed.read_only"),
        )
        updater = update_message(admin1)
        expect(updater.failed?).to eq(true)
        expect(updater.error.message).to eq(
          I18n.t("chat.errors.channel_modify_message_disallowed.read_only"),
        )
      end
    end

    context "when channel is archived" do
      before { public_chat_channel.update(status: :archived) }

      it "errors when trying to update the message for all users" do
        updater = update_message(user1)
        expect(updater.failed?).to eq(true)
        expect(updater.error.message).to eq(
          I18n.t("chat.errors.channel_modify_message_disallowed.archived"),
        )
        updater = update_message(admin1)
        expect(updater.failed?).to eq(true)
        expect(updater.error.message).to eq(
          I18n.t("chat.errors.channel_modify_message_disallowed.archived"),
        )
      end
    end
  end

  # TODO (martin) Remove this when we remove ChatUpload completely, 2023-04-01
  def chat_upload_count(uploads = nil)
    return DB.query_single("SELECT COUNT(*) FROM chat_uploads").first if !uploads
    DB.query_single(
      "SELECT COUNT(*) FROM chat_uploads WHERE upload_id IN (#{uploads.map(&:id).join(",")})",
    ).first
  end
end
