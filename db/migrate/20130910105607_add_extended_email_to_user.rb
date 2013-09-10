class AddExtendedEmailToUser < ActiveRecord::Migration
  def change
    add_column :users, :email_include_context, :boolean, default: true
    add_column :users, :email_new_topics, :boolean, default: false
    add_column :users, :email_digest_though_present, :boolean, default: false
    add_column :users, :email_notification_though_present, :boolean, default: false
  end
end
