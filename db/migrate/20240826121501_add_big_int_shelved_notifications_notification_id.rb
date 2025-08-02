# frozen_string_literal: true

class AddBigIntShelvedNotificationsNotificationId < ActiveRecord::Migration[7.0]
  def up
    # Create new column
    execute "ALTER TABLE shelved_notifications ADD COLUMN new_notification_id BIGINT NOT NULL DEFAULT 0"

    # Mirror new `notification_id` values to `new_notification_id`
    execute <<~SQL.squish
      CREATE FUNCTION mirror_user_badges_notification_id()
      RETURNS trigger AS
      $$
      BEGIN
        NEW.new_notification_id = NEW.notification_id;
        RETURN NEW;
      END;
      $$
      LANGUAGE plpgsql
    SQL

    execute <<~SQL.squish
      CREATE TRIGGER user_badges_new_notification_id_trigger BEFORE INSERT ON shelved_notifications
      FOR EACH ROW EXECUTE PROCEDURE mirror_user_badges_notification_id()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
