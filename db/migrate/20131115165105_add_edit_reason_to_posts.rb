class AddEditReasonToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :edit_reason, :string
  end
end
