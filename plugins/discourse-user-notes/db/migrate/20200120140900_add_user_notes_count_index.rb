# frozen_string_literal: true

class AddUserNotesCountIndex < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      DELETE
        FROM user_custom_fields a
       USING user_custom_fields b
       WHERE a.name = 'user_notes_count'
         AND a.name = b.name
         AND a.user_id = b.user_id
         AND a.id > b.id
    SQL

    add_index :user_custom_fields,
              %i[name user_id],
              unique: true,
              name: :idx_user_custom_fields_user_notes_count,
              where: "name = 'user_notes_count'"
  end

  def down
    remove_index :user_custom_fields, name: :idx_user_custom_fields_user_notes_count
  end
end
