# frozen_string_literal: true

class ChangeUploadsVerifiedToInteger < ActiveRecord::Migration[6.0]
  def up
    add_column :uploads, :verification_status, :integer, null: false, default: 1, index: true
    DB.exec(
      <<~SQL
      UPDATE uploads SET verification_status = CASE WHEN
        verified THEN 2
        WHEN NOT verified THEN 3
        ELSE 1
        END
      SQL
    )
  end

  def down
    if column_exists?(:uploads, :verification_status)
      remove_column :uploads, :verification_status
    end
  end
end
