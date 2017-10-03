class AddPasswordChangeIpToEmailTokens < ActiveRecord::Migration
  def up
    add_column :email_tokens, :remote_ip, :inet
    add_column :email_tokens, :user_agent, :string
  end

  def down
    remove_column :email_tokens, :remote_ip
    remove_column :email_tokens, :user_agent
  end
end
