class IndexEmailTokens < ActiveRecord::Migration
  def change
    add_index :email_tokens, [:user_id]
  end
end
