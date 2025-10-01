# frozen_string_literal: true
#
class RemoveFloatkitAutocompleteSiteSettings < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name IN ('floatkit_autocomplete_composer', 'floatkit_autocomplete_input_fields', 'floatkit_autocomplete_chat_composer')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
