class AlterIndexEmailOnUserEmails < ActiveRecord::Migration[5.1]
  def up
    execute("DROP INDEX index_user_emails_on_email")
    execute "CREATE UNIQUE INDEX index_user_emails_on_email ON user_emails (email);"
  end

  def down
    execute("DROP INDEX index_user_emails_on_email")
    execute "CREATE UNIQUE INDEX index_user_emails_on_email ON user_emails (lower(email));"
  end
end
