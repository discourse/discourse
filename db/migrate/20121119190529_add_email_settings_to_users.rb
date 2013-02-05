class AddEmailSettingsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :email_replied, :boolean, default: true
    add_column :users, :email_quoted, :boolean, default: true
  end
end
