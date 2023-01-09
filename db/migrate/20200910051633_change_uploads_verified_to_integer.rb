# frozen_string_literal: true

class ChangeUploadsVerifiedToInteger < ActiveRecord::Migration[6.0]
  def up
    add_column :uploads, :verification_status, :integer, null: false, default: 1
    Migration::ColumnDropper.mark_readonly(:uploads, :verified)

    DB.exec(<<~SQL)
      UPDATE uploads SET verification_status = CASE WHEN
        verified THEN 2
        WHEN NOT verified THEN 3
        ELSE 1
        END
      SQL
  end

  def down
    remove_column :uploads, :verification_status
  end
end
