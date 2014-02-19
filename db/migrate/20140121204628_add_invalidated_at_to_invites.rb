class AddInvalidatedAtToInvites < ActiveRecord::Migration
  def change
    add_column :invites, :invalidated_at, :datetime
  end
end
