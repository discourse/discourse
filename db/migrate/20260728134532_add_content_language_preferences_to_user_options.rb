# frozen_string_literal: true

class AddContentLanguagePreferencesToUserOptions < ActiveRecord::Migration[8.0]
  def up
    add_column :user_options, :automatically_translate, :boolean, default: true, null: false
    add_column :user_options, :understood_languages, :string, array: true, default: [], null: false

    execute <<~SQL
      UPDATE user_options
      SET automatically_translate = FALSE
      WHERE show_original_content = TRUE
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
