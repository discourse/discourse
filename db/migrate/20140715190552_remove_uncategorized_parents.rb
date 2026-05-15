# frozen_string_literal: true

class RemoveUncategorizedParents < ActiveRecord::Migration[4.2]
  def up
    uncat = execute("SELECT value FROM site_settings WHERE name = 'uncategorized_category_id'")
    row = uncat.first if uncat && uncat.ntuples > 0
    if row && row["value"]
      execute "UPDATE categories SET parent_category_id = NULL where id = #{row["value"].to_i}"
    end
  end

  def down
  end
end
