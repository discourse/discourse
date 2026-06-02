# frozen_string_literal: true

class FixFlagsIdSeqStart < ActiveRecord::Migration[8.0]
  MAX_SYSTEM_FLAG_ID = 1000

  def up
    execute "ALTER SEQUENCE flags_id_seq START WITH #{MAX_SYSTEM_FLAG_ID + 1}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
