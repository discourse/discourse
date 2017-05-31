class MakeUserAuthTokenIndexUnique < ActiveRecord::Migration
  def up
    remove_index :user_auth_tokens, [:auth_token]
    remove_index :user_auth_tokens, [:prev_auth_token]
    add_index :user_auth_tokens, [:auth_token], unique: true
    add_index :user_auth_tokens, [:prev_auth_token], unique: true
  end

  def down
    # no op, this should always have been unique
  end
end
