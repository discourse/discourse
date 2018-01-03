class RemoveWikiColor < ActiveRecord::Migration[4.2]
  def up
    execute "DELETE FROM color_scheme_colors WHERE name = 'wiki'"
  end

  def down
  end
end
