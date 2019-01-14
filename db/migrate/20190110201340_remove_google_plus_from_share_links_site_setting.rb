class RemoveGooglePlusFromShareLinksSiteSetting < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = array_to_string(array_remove(regexp_split_to_array(value, '\\|'), 'google+'), '|')
      WHERE name = 'share_links'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
