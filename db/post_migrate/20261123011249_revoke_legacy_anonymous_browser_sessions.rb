# frozen_string_literal: true

class RevokeLegacyAnonymousBrowserSessions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 500

  def up
    # Old processes could issue either a shadow or a master session by switching
    # identities. Neither token nor web push rows record their originating session.
    last_master_id = nil
    loop do
      master_ids = DB.query_single(<<~SQL, last_id: last_master_id, batch_size: BATCH_SIZE)
        SELECT DISTINCT master_user_id FROM anonymous_users
        WHERE (:last_id::integer IS NULL OR master_user_id > :last_id)
        ORDER BY master_user_id LIMIT :batch_size
      SQL
      break if master_ids.empty?

      connection.transaction do
        # Match the lock used by exchanges and push registration. Use separate
        # statements so cleanup sees writes committed while acquiring these locks.
        DB.exec(<<~SQL, ids: master_ids)
          SELECT id FROM users WHERE id IN (:ids) ORDER BY id FOR UPDATE
        SQL
        shadow_ids = DB.query_single(<<~SQL, ids: master_ids)
          SELECT user_id FROM anonymous_users WHERE master_user_id IN (:ids)
        SQL
        user_ids = master_ids | shadow_ids
        DB.exec("DELETE FROM user_auth_tokens WHERE user_id IN (:ids)", ids: user_ids)
        DB.exec("DELETE FROM push_subscriptions WHERE user_id IN (:ids)", ids: user_ids)
      end
      last_master_id = master_ids.last
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
