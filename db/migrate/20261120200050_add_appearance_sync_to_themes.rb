# frozen_string_literal: true

class AddAppearanceSyncToThemes < ActiveRecord::Migration[8.1]
  def change
    add_column :themes, :appearance_sync, :jsonb
  end
end
