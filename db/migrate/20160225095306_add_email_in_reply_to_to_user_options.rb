class AddEmailInReplyToToUserOptions < ActiveRecord::Migration[4.2]
  def up
    add_column :user_options, :email_in_reply_to, :boolean, null: false, default: true
    change_column :user_options, :email_previous_replies, :integer, default: 2, null: false
    execute 'UPDATE user_options SET email_previous_replies = 2'
  end

  def down
    remove_column :user_options, :email_in_reply_to
  end
end
