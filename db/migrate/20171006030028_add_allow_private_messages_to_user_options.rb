class AddAllowPrivateMessagesToUserOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :user_options, :allow_private_messages, :boolean, default: true, null: false
  end
end
