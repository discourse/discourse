# frozen_string_literal: true

%w[
  20240827040131_add_new_notification_id_to_chat_mention_notifications
  20240827040550_copy_chat_mention_notifications_notification_id_values
  20240827040810_copy_chat_mention_notifications_notification_id_indexes
  20240827040811_swap_bigint_chat_mention_notifications_notification_id
].each { |file| require Rails.root.join("plugins/chat/db/migrate/#{file}.rb") }

RSpec.describe "Migrate `ChatMentionNotification#notification_id` to bigint" do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Revert what migrations already did
    Migration::ColumnDropper.drop_readonly(:chat_mention_notifications, :old_notification_id)

    indexes =
      DB.query(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'chat_mention_notifications' AND indexdef SIMILAR TO '%\\mnotification_id\\M%'",
      ).map(&:indexdef)

    Migration::ColumnDropper.execute_drop(:chat_mention_notifications, [:notification_id])
    DB.exec "ALTER TABLE chat_mention_notifications RENAME COLUMN old_notification_id TO notification_id"

    indexes.each { |index| DB.exec(index) }
  end

  after do
    Notification.reset_column_information
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "correctly migrates the `notification_id` column to a bigint" do
    starting_indexes =
      DB
        .query(
          "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'chat_mention_notifications'",
        )
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    notification_1 = Fabricate(:notification)
    notification_2 = Fabricate(:notification)
    chat_mention_notification_1 =
      Fabricate(:chat_mention_notification, notification: notification_1)
    chat_mention_notification_2 =
      Fabricate(:chat_mention_notification, notification: notification_2)

    AddNewNotificationIdToChatMentionNotifications.new.up
    Chat::MentionNotification.reset_column_information

    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'chat_mention_notifications' AND column_name = 'new_notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    notification_3 = Fabricate(:notification)
    notification_3.reload
    chat_mention_notification_3 =
      Fabricate(:chat_mention_notification, notification: notification_3)

    # Check that the trigger to copy `notification_id` to `new_notification_id` was correctly created
    expect(
      DB.query(
        "SELECT 1 FROM chat_mention_notifications WHERE chat_mention_id = #{chat_mention_notification_3.chat_mention_id} AND new_notification_id = notification_id",
      )[
        0
      ].values,
    ).to eq([1])

    CopyChatMentionNotificationsNotificationIdValues.new.up
    CopyChatMentionNotificationsNotificationIdIndexes.new.up

    # Check that the rows were correctly copied
    [
      chat_mention_notification_1,
      chat_mention_notification_2,
      chat_mention_notification_3,
    ].each do |chat_mention_notification|
      expect(
        DB.query(
          "SELECT 1 FROM chat_mention_notifications WHERE chat_mention_id = #{chat_mention_notification.chat_mention_id} AND new_notification_id = notification_id",
        )[
          0
        ].values,
      ).to eq([1])
    end

    SwapBigintChatMentionNotificationsNotificationId.new.up

    # Check that columns were correctly swapped (notification_id -> old_notification_id, new_notification_id -> notification_id)
    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'chat_mention_notifications' AND column_name = 'notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    # Check that the old values are still present
    [
      chat_mention_notification_1,
      chat_mention_notification_2,
      chat_mention_notification_3,
    ].each do |chat_mention_notification|
      expect(
        DB.query(
          "SELECT 1 FROM chat_mention_notifications WHERE chat_mention_id = #{chat_mention_notification.chat_mention_id} AND old_notification_id = notification_id",
        )[
          0
        ].values,
      ).to eq([1])
    end

    # Check that the indexes were correctly recreated
    existing_indexes =
      DB
        .query(
          "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'chat_mention_notifications'",
        )
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    expect(existing_indexes.keys).to contain_exactly(*starting_indexes.keys)
    expect(existing_indexes.values).to contain_exactly(*starting_indexes.values)

    # Final smoke test to ensure that we can create a new user_badge
    Chat::MentionNotification.reset_column_information

    notification = Fabricate(:notification, id: 2_147_483_648)
    chat_mention_notification_4 = Fabricate(:chat_mention_notification, notification:)

    expect(chat_mention_notification_4.notification_id).to eq(2_147_483_648)
  end
end
