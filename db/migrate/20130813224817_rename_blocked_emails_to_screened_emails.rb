class RenameBlockedEmailsToScreenedEmails < ActiveRecord::Migration
  def change
    rename_table :blocked_emails, :screened_emails
  end
end
