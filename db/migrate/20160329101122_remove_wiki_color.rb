class RemoveWikiColor < ActiveRecord::Migration
  def up
    execute "DELETE FROM color_scheme_colors WHERE name = 'wiki'"
  end

  def down
  end
end
