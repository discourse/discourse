# frozen_string_literal: true

class RenameBannedToSuspended < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :banned_at,   :suspended_at
    rename_column :users, :banned_till, :suspended_till
  end
end
