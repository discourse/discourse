# frozen_string_literal: true
class UpdateCustomFlagSequence < ActiveRecord::Migration[7.1]
  def up
    # Update flags to consider the sequence when manual ids were added
    max_id = DB.query_single("SELECT MAX(id) from flags").first || Flag::MAX_SYSTEM_FLAG_ID
    DB.exec("SELECT setval('flags_id_seq', #{max_id + 1}, FALSE);")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
