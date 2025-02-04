# frozen_string_literal: true

class FixTosName < ActiveRecord::Migration[4.2]
  def up
    execute <<~SQL
      UPDATE user_fields
      SET name = 'Terms of Service'
      WHERE name = 'I have read and accept the <a href="/tos" target="_blank">Terms of Service</a>.'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
