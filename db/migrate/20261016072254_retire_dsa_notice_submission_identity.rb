# frozen_string_literal: true

class RetireDsaNoticeSubmissionIdentity < ActiveRecord::Migration[8.0]
  def up
    change_column_null :dsa_notices, :post_id, true
    change_column_null :dsa_notices, :submission_id, true
    change_column_null :dsa_notices, :reference, true
    Migration::ColumnDropper.mark_readonly(:dsa_notices, :submission_id)
    Migration::ColumnDropper.mark_readonly(:dsa_notices, :reference)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
