# frozen_string_literal: true

class AddBigIntNotificationsId < ActiveRecord::Migration[7.0]
  def up
    # Short-circuit if the table has been migrated already
    result =
      execute(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'id' LIMIT 1",
      )
    data_type = result[0]["data_type"]
    return if data_type.downcase == "bigint"

    # Create new column
    execute "ALTER TABLE notifications ADD COLUMN new_id BIGINT NOT NULL DEFAULT 0"

    # Mirror new `id` values to `new_id`
    execute <<~SQL.squish
      CREATE FUNCTION mirror_notifications_id()
      RETURNS trigger AS
      $$
      BEGIN
        NEW.new_id = NEW.id;
        RETURN NEW;
      END;
      $$
      LANGUAGE plpgsql
    SQL

    execute <<~SQL.squish
      CREATE TRIGGER notifications_new_id_trigger BEFORE INSERT ON notifications
      FOR EACH ROW EXECUTE PROCEDURE mirror_notifications_id()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
