class AddExternalLinksInNewTabAnDisableQuotingToUser < ActiveRecord::Migration
  def change
    add_column :users, :external_links_in_new_tab, :boolean, default: false, null: false
    add_column :users, :enable_quoting, :boolean, default: true, null: false
  end
end
