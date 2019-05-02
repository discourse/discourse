# frozen_string_literal: true

class RemoveS3ForcePathStyle < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 's3_force_path_style'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
