# frozen_string_literal: true

class AddColumnsToEmailLogToMatchIncomingForSmtpImap < ActiveRecord::Migration[6.1]
  def up
    add_column :email_logs, :cc_addresses, :text, null: true
    add_column :email_logs, :cc_user_ids, :integer, array: true, null: true
    add_column :email_logs, :raw, :text, null: true
    add_column :email_logs, :topic_id, :integer, null: true

    add_index :email_logs, :topic_id, where: "topic_id IS NOT NULL"
  end

  def down
    remove_column :email_logs, :cc_addresses if column_exists?(:email_logs, :cc_addresses)
    remove_column :email_logs, :cc_user_ids if column_exists?(:email_logs, :cc_user_ids)
    remove_column :email_logs, :raw if column_exists?(:email_logs, :raw)
    remove_column :email_logs, :topic_id if column_exists?(:email_logs, :topic_id)

    remove_index :email_logs, :topic_id if index_exists?(:email_logs, [:topic_id])
  end
end
