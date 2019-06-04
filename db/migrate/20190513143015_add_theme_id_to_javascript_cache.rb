# frozen_string_literal: true

class AddThemeIdToJavascriptCache < ActiveRecord::Migration[5.2]
  def up
    # Delete any javascript caches with broken foreign keys
    execute <<~SQL
      DELETE FROM javascript_caches jc
      WHERE  NOT EXISTS (
        SELECT 1
        FROM   theme_fields tf
        WHERE  tf.id = jc.theme_field_id
        );
    SQL
    make_changes
    execute "ALTER TABLE javascript_caches ADD CONSTRAINT enforce_theme_or_theme_field CHECK ((theme_id IS NOT NULL AND theme_field_id IS NULL) OR (theme_id IS NULL AND theme_field_id IS NOT NULL))"
  end
  def down
    execute "ALTER TABLE javascript_caches DROP CONSTRAINT enforce_theme_or_theme_field"
    revert { make_changes }
  end

  private

  def make_changes
    add_reference :javascript_caches, :theme, foreign_key: { on_delete: :cascade }
    add_foreign_key :javascript_caches, :theme_fields, on_delete: :cascade

    begin
      Migration::SafeMigrate.disable!
      change_column_null :javascript_caches, :theme_field_id, true
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end
