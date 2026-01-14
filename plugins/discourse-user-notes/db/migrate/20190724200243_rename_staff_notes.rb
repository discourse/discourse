# frozen_string_literal: true

class RenameStaffNotes < ActiveRecord::Migration[5.2]
  def change
    execute "UPDATE site_settings SET name = 'user_notes_enabled' WHERE name = 'staff_notes_enabled'"
  end
end
