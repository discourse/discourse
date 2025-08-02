# frozen_string_literal: true

class RemoveEditHistoryPublic < ActiveRecord::Migration[4.2]
  def up
    remove_column :user_options, :edit_history_public
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
