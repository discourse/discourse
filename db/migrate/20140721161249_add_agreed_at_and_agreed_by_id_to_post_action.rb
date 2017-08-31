class AddAgreedAtAndAgreedByIdToPostAction < ActiveRecord::Migration[4.2]
  def change
    add_column :post_actions, :agreed_at, :datetime
    add_column :post_actions, :agreed_by_id, :integer
  end
end
