# frozen_string_literal: true

class AddNormalizedEmailToUserEmail < ActiveRecord::Migration[6.1]
  def change
    add_column :user_emails, :normalized_email, :string
    execute "CREATE INDEX index_user_emails_on_normalized_email ON user_emails (LOWER(normalized_email))"
  end

  def down
    execute "DROP INDEX index_user_emails_on_normalized_email"
    drop_column :user_emails, :normalized_email, :string
  end
end
