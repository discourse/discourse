# frozen_string_literal: true

%w[
  20240826121501_add_big_int_shelved_notifications_notification_id
  20240826121502_copy_shelved_notifications_notification_id_values
  20240826121503_copy_shelved_notifications_notification_id_indexes
  20240826121504_swap_big_int_shelved_notifications_notification_id
].each { |file| require Rails.root.join("db/migrate/#{file}.rb") }

RSpec.describe "Migrate `ShelvedNotification#notification_id` to bigint" do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Revert what migrations already did
    Migration::ColumnDropper.drop_readonly(:shelved_notifications, :old_notification_id)
    indexes =
      DB.query(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'shelved_notifications' AND indexdef SIMILAR TO '%\\mnotification_id\\M%'",
      ).map(&:indexdef)
    Migration::ColumnDropper.execute_drop(:shelved_notifications, [:notification_id])
    DB.exec "ALTER TABLE shelved_notifications RENAME COLUMN old_notification_id TO notification_id"
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
          "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'shelved_notifications'",
        )
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    notification_1 = Fabricate(:notification)
    notification_2 = Fabricate(:notification)
    shelved_notification_1 = ShelvedNotification.create!(notification: notification_1)
    shelved_notification_2 = ShelvedNotification.create!(notification: notification_2)

    AddBigIntShelvedNotificationsNotificationId.new.up
    ShelvedNotification.reset_column_information

    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'shelved_notifications' AND column_name = 'new_notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    notification_3 = Fabricate(:notification)
    notification_3.reload
    shelved_notification_3 = ShelvedNotification.create!(notification: notification_3)

    # Check that the trigger to copy `notification_id` to `new_notification_id` was correctly created
    expect(shelved_notification_3.reload.new_notification_id).to eq(
      shelved_notification_3.notification_id,
    )

    CopyShelvedNotificationsNotificationIdValues.new.up
    CopyShelvedNotificationsNotificationIdIndexes.new.up

    # Check that the rows were correctly copied
    [
      shelved_notification_1,
      shelved_notification_2,
      shelved_notification_3,
    ].each do |shelved_notification|
      result =
        DB.query(
          "SELECT 1 FROM shelved_notifications WHERE id = #{shelved_notification.id} AND new_notification_id = notification_id",
        )[
          0
        ].values

      expect(result).to eq([1])
    end

    SwapBigIntShelvedNotificationsNotificationId.new.up

    # Check that columns were correctly swapped (notification_id -> old_notification_id, new_notification_id -> notification_id)
    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'shelved_notifications' AND column_name = 'notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    # Check that the old values are still present
    [
      shelved_notification_1,
      shelved_notification_2,
      shelved_notification_3,
    ].each do |shelved_notification|
      result =
        DB.query(
          "SELECT 1 FROM shelved_notifications WHERE id = #{shelved_notification.id} AND old_notification_id = notification_id",
        )[
          0
        ].values

      expect(result).to eq([1])
    end

    # Check that the indexes were correctly recreated
    existing_indexes =
      DB
        .query(
          "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'shelved_notifications'",
        )
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    expect(existing_indexes.keys).to contain_exactly(*starting_indexes.keys)
    expect(existing_indexes.values).to contain_exactly(*starting_indexes.values)

    # Final smoke test to ensure that we can create a new shelved_notification
    ShelvedNotification.reset_column_information
    shelved_notification_4 = ShelvedNotification.create!(notification_id: 2_147_483_648)

    expect(shelved_notification_4.notification_id).to eq(2_147_483_648)
  end
end
