class AddEmailPreviousRepliesToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :email_previous_replies, :integer, null: false, default: 1
  end
end
