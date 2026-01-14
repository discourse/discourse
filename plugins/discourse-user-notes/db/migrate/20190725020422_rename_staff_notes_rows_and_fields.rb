# frozen_string_literal: true

class RenameStaffNotesRowsAndFields < ActiveRecord::Migration[5.2]
  def change
    execute "UPDATE user_custom_fields SET name = 'user_notes_count' WHERE name = 'staff_notes_count'"
    execute "UPDATE plugin_store_rows SET plugin_name = 'user_notes' WHERE plugin_name = 'staff_notes'"
  end
end
