# frozen_string_literal: true

class AddIndexToUploadsVerificationStatus < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      idx_uploads_on_verification_status ON uploads USING btree (verification_status)
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS idx_uploads_on_verification_status"
  end
end
