class AddDisableJumpReplyToUsers < ActiveRecord::Migration
  def change
    add_column :users, :disable_jump_reply, :boolean, default: false, null: false
  end
end
