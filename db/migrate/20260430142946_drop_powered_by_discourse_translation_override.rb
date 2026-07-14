# frozen_string_literal: true
class DropPoweredByDiscourseTranslationOverride < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM translation_overrides WHERE translation_key = 'js.powered_by_discourse'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
