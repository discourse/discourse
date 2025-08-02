# frozen_string_literal: true
class AddTriggerToUsersToSyncUserPasswords < ActiveRecord::Migration[7.1]
  def up
    # necessary for postgres < v14 which does not have CREATE OR REPLACE TRIGGER
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS
      users_password_sync ON users;
    SQL

    execute <<~SQL.squish
    CREATE OR REPLACE FUNCTION mirror_user_password_data() RETURNS TRIGGER AS $$
    BEGIN
      INSERT INTO user_passwords (user_id, password_hash, password_salt, password_algorithm, password_expired_at, created_at, updated_at)
      VALUES (NEW.id, NEW.password_hash, NEW.salt, NEW.password_algorithm, NULL, now(), now())
      ON CONFLICT(user_id)
      DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        password_salt = EXCLUDED.password_salt,
        password_algorithm = EXCLUDED.password_algorithm,
        password_expired_at = EXCLUDED.password_expired_at,
        updated_at = now()
        WHERE user_passwords.password_hash <> EXCLUDED.password_hash;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL.squish
      CREATE TRIGGER users_password_sync
      AFTER INSERT OR UPDATE OF password_hash ON users
      FOR EACH ROW
      WHEN (NEW.password_hash IS NOT NULL)
      EXECUTE PROCEDURE mirror_user_password_data();
    SQL

    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS
      users_password_sync_on_delete_password ON users;
    SQL

    execute <<~SQL.squish
    CREATE OR REPLACE FUNCTION delete_user_password() RETURNS TRIGGER AS $$
    BEGIN
      DELETE FROM user_passwords WHERE user_id = NEW.id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL.squish
      CREATE TRIGGER users_password_sync_on_delete_password
      AFTER UPDATE OF password_hash ON users
      FOR EACH ROW
      WHEN (NEW.password_hash IS NULL)
      EXECUTE PROCEDURE delete_user_password();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS users_password_sync_on_delete_password ON users;
      DROP FUNCTION IF EXISTS delete_user_password;
      DROP TRIGGER IF EXISTS users_password_sync ON users;
      DROP FUNCTION IF EXISTS mirror_user_password_data;
    SQL
  end
end
