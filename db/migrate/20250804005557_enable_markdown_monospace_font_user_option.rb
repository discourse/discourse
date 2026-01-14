# frozen_string_literal: true
class EnableMarkdownMonospaceFontUserOption < ActiveRecord::Migration[8.0]
  def up
    add_column :user_options, :enable_markdown_monospace_font, :boolean, default: true, null: false

    if Migration::Helpers.existing_site?
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('default_other_enable_markdown_monospace_font', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL

      execute <<~SQL
        UPDATE user_options
        SET enable_markdown_monospace_font = false
      SQL
    end
  end

  def down
    if column_exists?(:user_options, :enable_markdown_monospace_font)
      remove_column :user_options, :enable_markdown_monospace_font
    end

    execute <<~SQL if Migration::Helpers.existing_site?
      DELETE FROM site_settings WHERE name = 'default_other_enable_markdown_monospace_font'
    SQL
  end
end
