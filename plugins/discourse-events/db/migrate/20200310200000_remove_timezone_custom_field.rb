# frozen_string_literal: true

class RemoveTimezoneCustomField < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM user_custom_fields WHERE name = 'timezone'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
