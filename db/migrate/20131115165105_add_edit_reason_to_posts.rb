class AddEditReasonToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :edit_reason, :string
  end
end
