# frozen_string_literal: true
class BackfillUserPasswordsFromUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  BATCH_SIZE = 50_000

  def up
    min_id, max_id = DB.query_single(<<~SQL.squish)
      SELECT MIN(id), MAX(id)
      FROM users
      WHERE password_hash IS NOT NULL AND salt IS NOT NULL AND password_algorithm IS NOT NULL;
    SQL

    return if max_id.nil?

    (min_id..max_id).step(BATCH_SIZE) { |start_id| execute <<~SQL }
      INSERT INTO user_passwords (user_id, password_hash, password_salt, password_algorithm, password_expired_at, created_at, updated_at)
      SELECT id, password_hash, salt, password_algorithm, NULL, now(), now()
      FROM users
      WHERE id >= #{start_id} AND id < #{start_id + BATCH_SIZE} AND password_hash IS NOT NULL AND salt IS NOT NULL AND password_algorithm IS NOT NULL
      ON CONFLICT (user_id) DO UPDATE SET
        password_hash = EXCLUDED.password_hash,
        password_salt = EXCLUDED.password_salt,
        password_algorithm = EXCLUDED.password_algorithm,
        password_expired_at = EXCLUDED.password_expired_at,
        updated_at = now()
      WHERE user_passwords.password_hash <> EXCLUDED.password_hash
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
