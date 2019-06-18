# frozen_string_literal: true

class SplitPublicInGroups < ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :public_exit, :boolean, default: false, null: false
    add_column :groups, :public_admission, :boolean, default: false, null: false

    DB.exec <<~SQL
    UPDATE groups
    SET public_exit = true, public_admission = true
    WHERE public = true
    SQL
  end

  def down
    remove_column :groups, :public_exit
    remove_column :groups, :public_admission
  end
end
