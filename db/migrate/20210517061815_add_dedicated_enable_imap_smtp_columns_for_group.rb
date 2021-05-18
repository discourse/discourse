# frozen_string_literal: true

class AddDedicatedEnableImapSmtpColumnsForGroup < ActiveRecord::Migration[6.1]
  def up
    add_column :groups, :smtp_enabled, :boolean, default: false
    add_column :groups, :smtp_updated_at, :datetime, null: true
    add_column :groups, :smtp_updated_by_id, :integer, null: true

    add_column :groups, :imap_enabled, :boolean, default: false
    add_column :groups, :imap_updated_at, :datetime, null: true
    add_column :groups, :imap_updated_by_id, :integer, null: true

    DB.exec(<<~SQL)
      UPDATE groups SET smtp_enabled = true, smtp_updated_at = NOW(), smtp_updated_by_id = -1
      WHERE smtp_port IS NOT NULL AND smtp_server IS NOT NULL AND email_username IS NOT NULL AND email_password IS NOT NULL AND
      smtp_server != '' AND email_username != '' AND email_password != ''
    SQL

    DB.exec(<<~SQL)
      UPDATE groups SET imap_enabled = true, imap_updated_at = NOW(), imap_updated_by_id = -1
      WHERE imap_port IS NOT NULL AND imap_server IS NOT NULL AND email_username IS NOT NULL AND email_password IS NOT NULL AND
      imap_server != '' AND email_username != '' AND email_password != ''
    SQL
  end

  def down
    remove_column :groups, :smtp_enabled
    remove_column :groups, :smtp_updated_at
    remove_column :groups, :smtp_updated_by_id

    remove_column :groups, :imap_enabled
    remove_column :groups, :imap_updated_at
    remove_column :groups, :imap_updated_by_id
  end
end
