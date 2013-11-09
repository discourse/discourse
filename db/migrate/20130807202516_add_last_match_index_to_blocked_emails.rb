class AddLastMatchIndexToBlockedEmails < ActiveRecord::Migration
  def change
    add_index :blocked_emails, :last_match_at
  end
end
