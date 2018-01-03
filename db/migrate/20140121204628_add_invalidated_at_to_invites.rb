class AddInvalidatedAtToInvites < ActiveRecord::Migration[4.2]
  def change
    add_column :invites, :invalidated_at, :datetime
  end
end
