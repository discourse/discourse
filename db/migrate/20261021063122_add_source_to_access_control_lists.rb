# frozen_string_literal: true
class AddSourceToAccessControlLists < ActiveRecord::Migration[8.1]
  def up
    add_column :access_control_lists, :source, :string, limit: 100
    execute "UPDATE access_control_lists SET source = owner"
    change_column_null :access_control_lists, :owner, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
