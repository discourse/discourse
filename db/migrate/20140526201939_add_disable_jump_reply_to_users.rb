class AddDisableJumpReplyToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :disable_jump_reply, :boolean, default: false, null: false
  end
end
