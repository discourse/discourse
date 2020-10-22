# frozen_string_literal: true

class AddImapGroupIdToIncomingEmail < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      ALTER TABLE incoming_emails ADD COLUMN IF NOT EXISTS imap_group_id bigint NULL
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      index_incoming_emails_on_imap_group_id ON incoming_emails USING btree (imap_group_id)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE incoming_emails DROP COLUMN IF EXISTS imap_group_id
    SQL
  end
end
