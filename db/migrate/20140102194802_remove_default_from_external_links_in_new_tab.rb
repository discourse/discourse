class RemoveDefaultFromExternalLinksInNewTab < ActiveRecord::Migration
  def up
    change_column_default :users, :external_links_in_new_tab, nil
  end

  def down
    change_column_default :users, :external_links_in_new_tab, false
  end
end
