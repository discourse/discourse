# frozen_string_literal: true

%w[
  20240826121505_add_big_int_user_badges_notification_id
  20240826121506_copy_user_badges_notification_id_values
  20240826121507_swap_big_int_user_badges_notification_id
].each { |file| require Rails.root.join("db/migrate/#{file}.rb") }

RSpec.describe "Migrate `UserBadge#notification_id` to bigint" do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Revert what migrations already did
    Migration::ColumnDropper.drop_readonly(:user_badges, :old_notification_id)
    indexes =
      DB.query(
        "SELECT indexdef FROM pg_indexes WHERE tablename = 'user_badges' AND indexdef SIMILAR TO '%\\mnotification_id\\M%'",
      ).map(&:indexdef)
    Migration::ColumnDropper.execute_drop(:user_badges, [:notification_id])
    DB.exec "ALTER TABLE user_badges RENAME COLUMN old_notification_id TO notification_id"
    indexes.each { |index| DB.exec(index) }
  end

  after do
    Notification.reset_column_information
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "correctly migrates the `notification_id` column to a bigint" do
    starting_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'user_badges'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    notification_1 = Fabricate(:notification)
    notification_2 = Fabricate(:notification)
    user_badge_1 = Fabricate(:user_badge, notification: notification_1)
    user_badge_2 = Fabricate(:user_badge, notification: notification_2)

    AddBigIntUserBadgesNotificationId.new.up
    UserBadge.reset_column_information

    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'user_badges' AND column_name = 'new_notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    notification_3 = Fabricate(:notification)
    notification_3.reload
    user_badge_3 = Fabricate(:user_badge, notification: notification_3)

    # Check that the trigger to copy `notification_id` to `new_notification_id` was correctly created
    result =
      DB.query(
        "SELECT 1 FROM user_badges WHERE id = #{user_badge_3.id} AND new_notification_id = notification_id",
      )[
        0
      ].values

    expect(result).to eq([1])

    CopyUserBadgesNotificationIdValues.new.up

    # Check that the rows were correctly copied
    [user_badge_1, user_badge_2, user_badge_3].each do |user_badge|
      result =
        DB.query(
          "SELECT 1 FROM user_badges WHERE id = #{user_badge.id} AND new_notification_id = notification_id",
        )[
          0
        ].values

      expect(result).to eq([1])
    end

    SwapBigIntUserBadgesNotificationId.new.up

    # Check that columns were correctly swapped (notification_id -> old_notification_id, new_notification_id -> notification_id)
    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'user_badges' AND column_name = 'notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    # Check that the old values are still present
    [user_badge_1, user_badge_2, user_badge_3].each do |user_badge|
      result =
        DB.query(
          "SELECT 1 FROM user_badges WHERE id = #{user_badge.id} AND old_notification_id = notification_id",
        )[
          0
        ].values

      expect(result).to eq([1])
    end

    # Check that the indexes were correctly recreated
    existing_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'user_badges'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    expect(existing_indexes.keys).to contain_exactly(*starting_indexes.keys)
    expect(existing_indexes.values).to contain_exactly(*starting_indexes.values)

    # Final smoke test to ensure that we can create a new user_badge
    UserBadge.reset_column_information
    user_badge_4 = Fabricate(:user_badge, notification_id: 2_147_483_648)

    expect(user_badge_4.notification_id).to eq(2_147_483_648)
  end
end
