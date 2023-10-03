# frozen_string_literal: true

# This plugin related index was added to core way back in 2018 but it should not have been added to core in the first place.
# The index has since been moved into the plugin itself.
class DropIdxPostCustomFieldsAkismet < ActiveRecord::Migration[7.0]
  def up
    execute "DROP INDEX IF EXISTS idx_post_custom_fields_akismet"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
