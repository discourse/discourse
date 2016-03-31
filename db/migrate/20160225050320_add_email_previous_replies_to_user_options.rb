class AddEmailPreviousRepliesToUserOptions < ActiveRecord::Migration
  def change
    add_column :user_options, :email_previous_replies, :integer, null: false, default: 1
  end
end
