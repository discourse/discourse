class AddHiddenToPostRevision < ActiveRecord::Migration
  def change
    add_column :post_revisions, :hidden, :boolean, null: false, default: false
  end
end
