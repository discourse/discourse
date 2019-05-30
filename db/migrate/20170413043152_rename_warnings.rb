# frozen_string_literal: true

class RenameWarnings < ActiveRecord::Migration[4.2]
  def up
    rename_table :warnings, :user_warnings
  end

  def down
    rename_table :user_warnings, :warnings
  end
end
