# frozen_string_literal: true

class DropDsaNoticeSubmissionIdentity < ActiveRecord::Migration[8.0]
  def up
    Migration::ColumnDropper.execute_drop(:dsa_notices, %i[submission_id reference])
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
