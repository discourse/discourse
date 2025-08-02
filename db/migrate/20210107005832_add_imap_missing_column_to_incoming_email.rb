# frozen_string_literal: true

class AddImapMissingColumnToIncomingEmail < ActiveRecord::Migration[6.0]
  def change
    add_column :incoming_emails, :imap_missing, :boolean, default: false, null: false
  end
end
