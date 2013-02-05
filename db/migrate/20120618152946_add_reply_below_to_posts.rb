class AddReplyBelowToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :reply_below_post_number, :integer, null: true
  end
end
