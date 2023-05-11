# frozen_string_literal: true

class AddSmtpAndImapToGroups < ActiveRecord::Migration[5.2]
  def change
    add_column :groups, :smtp_server, :string
    add_column :groups, :smtp_port, :integer
    add_column :groups, :smtp_ssl, :boolean

    add_column :groups, :imap_server, :string
    add_column :groups, :imap_port, :integer
    add_column :groups, :imap_ssl, :boolean

    add_column :groups, :imap_mailbox_name, :string, default: "", null: false
    add_column :groups, :imap_uid_validity, :integer, default: 0, null: false
    add_column :groups, :imap_last_uid, :integer, default: 0, null: false

    add_column :groups, :email_username, :string
    add_column :groups, :email_password, :string
  end
end
