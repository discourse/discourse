# frozen_string_literal: true

class RenameBlockedEmailsToScreenedEmails < ActiveRecord::Migration[4.2]
  def change
    rename_table :blocked_emails, :screened_emails
  end
end
