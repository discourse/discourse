# frozen_string_literal: true

%w[
  20240820123401_add_big_int_notifications_id
  20240820123402_copy_notifications_id_values
  20240820123403_swap_big_int_notifications_id
  20240820123404_alter_notifications_id_sequence_to_bigint
].each { |file| require Rails.root.join("db/migrate/#{file}.rb") }

RSpec.describe "Migrate `Notifications#id` to bigint" do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Revert what migrations already did
    Migration::ColumnDropper.drop_readonly(:notifications, :old_id)
    DB.exec "ALTER SEQUENCE notifications_id_seq AS INT OWNED BY notifications.old_id"
    Migration::ColumnDropper.execute_drop(:notifications, [:id])
    DB.exec "ALTER TABLE notifications RENAME COLUMN old_id TO id"
    DB.exec "ALTER TABLE notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass)"
    DB.exec "CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id)"
    DB.exec "ALTER TABLE notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY USING INDEX notifications_pkey"
  end

  after do
    Notification.reset_column_information
    ActiveRecord::Migration.verbose = @original_verbose
  end

  it "correctly migrates the `id` column to a bigint" do
    starting_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    notification_1 = Fabricate(:notification)
    notification_2 = Fabricate(:notification)

    AddBigIntNotificationsId.new.up
    AlterNotificationsIdSequenceToBigint.new.up

    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'new_id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    notification_3 = Fabricate(:notification)
    notification_3.reload

    # Check that the trigger to copy `id` to `new_id` was correctly created
    expect(notification_3.new_id).to eq(notification_3.id)

    CopyNotificationsIdValues.new.up

    # Check that the rows were correctly copied
    expect(notification_1.reload.new_id).to eq(notification_1.id)
    expect(notification_2.reload.new_id).to eq(notification_2.id)
    expect(notification_3.reload.new_id).to eq(notification_3.id)

    SwapBigIntNotificationsId.new.up

    # Check that columns were correctly swapped (id -> old_id, new_id -> id)
    expect(
      DB.query(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'id' LIMIT 1",
      )[
        0
      ].data_type,
    ).to eq("bigint")

    # Check that the old values are still present
    expect(notification_1.reload.old_id).to eq(notification_1.id)

    # Check that the indexes were correctly recreated
    existing_indexes =
      DB
        .query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications'")
        .reduce({}) do |acc, result|
          acc[result.indexname] = result.indexdef
          acc
        end

    expect(existing_indexes.keys).to contain_exactly(
      *starting_indexes.keys,
      "index_notifications_read_or_not_high_priority_bigint",
      "index_notifications_unique_unread_high_priority_bigint",
    )

    # Final smoke test to ensure that we can create a new notification
    DB.exec("SELECT setval('notifications_id_seq', 2147483647)") # Set to bigint
    Notification.reset_column_information
    notification_4 = Fabricate(:notification)

    expect(notification_4.id).to eq(2_147_483_648)
  end
end
