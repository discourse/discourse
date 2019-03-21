class IndexEmailTokens < ActiveRecord::Migration[4.2]
  def change
    add_index :email_tokens, %i[user_id]
  end
end
