# frozen_string_literal: true

class AddImapStatsToGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :imap_last_error, :text
    add_column :groups, :imap_old_emails, :integer
    add_column :groups, :imap_new_emails, :integer
  end
end
