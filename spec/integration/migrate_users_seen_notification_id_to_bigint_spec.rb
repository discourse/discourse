# frozen_string_literal: true

%w[
  20240827063715_add_new_seen_notification_id_to_users
  20240827063908_copy_users_seen_notification_id_values
  20240827064121_swap_seen_notification_id_with_seen_notification_id_on_users
].each { |file| require Rails.root.join("db/migrate/#{file}.rb") }

RSpec.describe "Migrate `Users#seen_notification_id` to bigint" do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Revert what migrations already did
    Migration::ColumnDropper.drop_readonly(:users, :old_seen_notification_id)
    Migration::ColumnDropper.execute_drop(:users, [:seen_notification_id])
    DB.exec "ALTER TABLE users RENAME COLUMN old_seen_notification_id TO seen_notification_id"
    DB.exec <<~SQL
    UPDATE users
    SET seen_notification_id = 0
    WHERE seen_notification_id IS NULL
    SQL
    DB.exec "ALTER TABLE users ALTER COLUMN seen_notification_id SET DEFAULT(0)"
    DB.exec "ALTER TABLE users ALTER COLUMN seen_notification_id SET NOT NULL"
  end

  after do
    Notification.reset_column_information
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "correctly migrates the `notification_id` column to a bigint" do
    starting_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'users'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    user_1 = Fabricate(:user)
    user_2 = Fabricate(:user)
    notification_1 = Fabricate(:notification, user: user_1)
    notification_2 = Fabricate(:notification, user: user_2)
    user_1.update!(seen_notification_id: notification_1.id)
    user_2.update!(seen_notification_id: notification_2.id)

    AddNewSeenNotificationIdToUsers.new.up
    User.reset_column_information

    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'new_seen_notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    user_3 = Fabricate(:user)
    notification_3 = Fabricate(:notification)
    notification_3.reload
    user_3.update!(seen_notification_id: notification_3.id)

    # Check that the trigger to copy `seen_notification_id` to `new_seen_notification_id` was correctly created
    expect(
      DB.query(
        "SELECT seen_notification_id, new_seen_notification_id FROM users WHERE id = #{user_3.id}",
      )[
        0
      ].values,
    ).to eq([notification_3.id, notification_3.id])

    CopyUsersSeenNotificationIdValues.new.up

    # Check that the rows were correctly copied
    expect(
      DB.query(
        "SELECT seen_notification_id, new_seen_notification_id FROM users WHERE id = #{user_1.id}",
      )[
        0
      ].values,
    ).to eq([notification_1.id, notification_1.id])

    expect(
      DB.query(
        "SELECT seen_notification_id, new_seen_notification_id FROM users WHERE id = #{user_2.id}",
      )[
        0
      ].values,
    ).to eq([notification_2.id, notification_2.id])

    expect(
      DB.query(
        "SELECT seen_notification_id, new_seen_notification_id FROM users WHERE id = #{user_3.id}",
      )[
        0
      ].values,
    ).to eq([notification_3.id, notification_3.id])

    SwapSeenNotificationIdWithSeenNotificationIdOnUsers.new.up

    # Check that columns were correctly swapped (seen_notification_id -> old_seen_notification_id, new_seen_notification_id -> seen_notification_id)
    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'seen_notification_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    # Check that the old values are still present
    [user_1, user_2, user_3].each do |user|
      result =
        DB.query(
          "SELECT 1 FROM users WHERE id = #{user.id} AND old_seen_notification_id = seen_notification_id",
        )[
          0
        ].values

      expect(result).to eq([1])
    end

    # Check that the indexes were correctly recreated
    existing_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'users'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    expect(existing_indexes.keys).to contain_exactly(*starting_indexes.keys)
    expect(existing_indexes.values).to contain_exactly(*starting_indexes.values)

    # Final smoke test to ensure that we can create a new shelved_notification
    User.reset_column_information
    user = Fabricate(:user, seen_notification_id: 2_147_483_648)

    expect(user.seen_notification_id).to eq(2_147_483_648)
  end
end
