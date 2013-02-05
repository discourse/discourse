class AddDeletedAtToInvites < ActiveRecord::Migration
  def change
    add_column :invites, :deleted_at, :datetime
  end
end
