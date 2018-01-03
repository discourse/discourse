class AddHiddenToPostRevision < ActiveRecord::Migration[4.2]
  def change
    add_column :post_revisions, :hidden, :boolean, null: false, default: false
  end
end
