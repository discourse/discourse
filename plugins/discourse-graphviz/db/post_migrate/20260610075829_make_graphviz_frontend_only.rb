# frozen_string_literal: true
class MakeGraphvizFrontendOnly < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'graphviz_default_svg'"

    # Rebake existing graphviz posts so their stored HTML matches the current output.
    execute <<~SQL
      UPDATE posts
      SET baked_version = 0
      WHERE raw LIKE '%[graphviz]%'
        OR raw LIKE '%[graphviz %'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
