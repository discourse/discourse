# frozen_string_literal: true
class AddNewNotificationIdToChatMentionNotifications < ActiveRecord::Migration[7.1]
  def up
    # Create new column
    execute "ALTER TABLE chat_mention_notifications ADD COLUMN new_notification_id BIGINT NOT NULL DEFAULT(0)"

    # Mirror new `notification_id` values to `new_notification_id`
    execute(<<~SQL)
      CREATE FUNCTION mirror_chat_mention_notifications_notification_id()
      RETURNS trigger AS
      $$
      BEGIN
        NEW.new_notification_id = NEW.notification_id;
        RETURN NEW;
      END;
      $$
      LANGUAGE plpgsql
    SQL

    execute(<<~SQL)
      CREATE TRIGGER chat_mention_notifications_new_notification_id_trigger BEFORE INSERT ON chat_mention_notifications
      FOR EACH ROW EXECUTE PROCEDURE mirror_chat_mention_notifications_notification_id()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
