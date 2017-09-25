class RemoveUncategorizedParents < ActiveRecord::Migration[4.2]
  def up
    uncat = execute("SELECT value FROM site_settings WHERE name = 'uncategorized_category_id'")
    if uncat && uncat[0] && uncat[0]['value']
      execute "UPDATE categories SET parent_category_id = NULL where id = #{uncat[0]['value'].to_i}"
    end
  end

  def down
  end
end
