class RemoveEnglishFromPostActionTypes < ActiveRecord::Migration
  def up
    rename_column :post_action_types, :name, :name_key
    execute "UPDATE post_action_types SET name_key = regexp_replace(lower(name_key), '[^a-z]', '_')"
    remove_column :post_action_types, :long_form
    remove_column :post_action_types, :description
  end

  def down
  end
end
