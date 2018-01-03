class AddDeletedAtToInvites < ActiveRecord::Migration[4.2]
  def change
    add_column :invites, :deleted_at, :datetime
  end
end
