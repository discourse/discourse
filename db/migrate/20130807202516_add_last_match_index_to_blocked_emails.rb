class AddLastMatchIndexToBlockedEmails < ActiveRecord::Migration[4.2]
  def change
    add_index :blocked_emails, :last_match_at
  end
end
